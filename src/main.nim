import
    nsdl,
    mpv

const
    WinW = 1280
    WinH = 800

nsdl.init(Video or Events, should_init_ttf = true)
let (window, renderer) = create_window_and_renderer("PMM", WinW, WinH)

renderer.set_draw_colour Grey

var running = true
while running:
    for event in get_events():
        case event.kind
        of Quit:
            running = false
        of Keydown:
            case event.key.keysym.sym
            of KeyEscape:
                running = false
            else:
                discard
        else:
            discard

    fill renderer
    present renderer

destroy window
nsdl.quit()
