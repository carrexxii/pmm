import
    nsdl,
    common, mpv
from std/sugar import `=>`

var
    winw = 1280
    winh = 800

nsdl.init(Video or Events, should_init_ttf = true)
let (window, renderer) = create_window_and_renderer("PMM", winw, winh, Resizeable)
renderer.set_vsync 0
renderer.set_draw_colour Grey

let mpv_ctx = mpv.create()
mpv_ctx.set_property("vo", "libmpv")
init mpv_ctx

let
    one = cint 1
    gl_init_params = OpenGLInitParamsObj(get_proc_address: (ctx: pointer, name: cstring) => gl_get_proc_address name)
    render_params = [
        render_param(APIType, cstring "opengl"),
        render_param(OpenGLInitParams, gl_init_params.addr),
        render_param(AdvancedControl, one.addr),
        render_param(Invalid, nil),
    ]

let mpv_gl = mpv_ctx.create_render_context render_params

let
    wakeup_on_mpv_render_update = register_event()
    wakeup_on_mpv_events        = register_event()

mpv_ctx.set_wakeup_cb (ctx: pointer) => push_event Event(kind: nsdl.EventKind wakeup_on_mpv_events)

let cmd = [cstring "loadfile", cstring "test.mp4", nil]
mpv_ctx.command_async("loadfile", "test.mp4")
mpv_gl.set_update_cb (ctx: pointer) => push_event Event(kind: nsdl.EventKind wakeup_on_mpv_render_update)

echo &"Initialized SDL ({nsdl.get_version()}) and MPV ({mpv.get_version()})"
echo &"\tMPV Client -> {mpv_ctx.client_name} ({mpv_ctx.client_id})"

var
    bufferw = 960
    bufferh = 640
    buffer = renderer.create_texture(bufferw, bufferh, access = Target)
let buffer_fbo = 2'i32 # IDK how to get this (tried texture properties)

var need_redraw = true
var running     = true
while running:
    for event in get_events():
        case event.kind
        of Quit:
            running = false
        of WindowExposed:
            need_redraw = true
        of Keydown:
            case event.key.keysym.sym
            of KeyEscape:
                running = false
            else:
                discard
        else:
            if event.kind == nsdl.EventKind wakeup_on_mpv_render_update:
                let flags = update mpv_gl
                if flags == Frame:
                    need_redraw = true
            elif event.kind == nsdl.EventKind wakeup_on_mpv_events:
                for mpv_event in mpv_ctx.get_events():
                    case mpv_event.kind
                    of LogMessage:
                        let log_obj = cast[ptr EventLogMessageObj](mpv_event.data)[]
                        echo log_obj
                    else:
                        echo mpv_event.kind

    if need_redraw:
        need_redraw = false
        let
            one = cint 1
            fbo_obj = opengl_fbo(bufferw, bufferh, fbo = buffer_fbo)
            params = [
                render_param(OpenGLFBO, fbo_obj.addr),
                render_param(Invalid, nil),
            ]

        renderer.set_target buffer
        mpv_gl.render params
        flush renderer

        renderer.reset_target

        renderer.draw_texture(buffer, dst_rect = frect(200, 200, bufferw, bufferh))

        renderer.set_draw_colour Blue
        renderer.draw_fill_rect frect(100, 100, 200, 200)

        report_swap mpv_gl
        present renderer

destroy mpv_gl
destroy mpv_ctx
destroy window
nsdl.quit()
