{.push raises: [].}

from std/strformat import `&`
from std/sugar     import `->`

type MPVError* = object of CatchableError

func make_version*(major, minor: int): int =
    (major shl 16) or minor
const ClientAPIVersion* = make_version(2, 3)

type
    ErrorCode* {.size: sizeof(cint).} = enum
        Generic             = -20
        NotImplemented      = -19
        Unsupported         = -18
        UnknownError        = -17
        NothingToPlay       = -16
        VOInitFailed        = -15
        AOInitFailed        = -14
        LoadingFailed       = -13
        Command             = -12
        PropertyError       = -11
        PropertyUnavailable = -10
        PropertyFormat      = -9
        PropertyNotFound    = -8
        OptionError         = -7
        OptionFormat        = -6
        OptionNotFound      = -5
        InvalidParameter    = -4
        Uninitialized       = -3
        NoMem               = -2
        EventQueueFull      = -1
        Success             = 0

    LogLevel* {.size: sizeof(cint).} = enum
        None  = 0
        Fatal = 10
        Error = 20
        Warn  = 30
        Info  = 40
        V     = 50
        Debug = 60
        Trace = 70

    Format* {.size: sizeof(cint).} = enum
        None
        String
        OSDString
        Flag
        Int64
        Double
        Node
        NodeArray
        NodeMap
        ByteArray

    EventKind* {.size: sizeof(cint).} = enum
        None             = 0
        Shutdown         = 1
        LogMessage       = 2
        GetPropertyReply = 3
        SetPropertyReply = 4
        CommandReply     = 5
        StartFile        = 6
        EndFile          = 7
        FileLoaded       = 8
        ClientMessage    = 16
        VideoReconfig    = 17
        AudioReconfig    = 18
        Seek             = 20
        PlaybackRestart  = 21
        PropertyChange   = 22
        QueueOverflow    = 24
        Hook             = 25

    EndFileReason* {.size: sizeof(cint).} = enum
        EOF      = 0
        Stop     = 2
        Quit     = 3
        Error    = 4
        Redirect = 5

func `$`*(kind: EventKind): string =
    let n = int kind
    if (n >= 0  and n <= 8) or
       (n >= 16 and n <= 25) and n != 23:
        repr kind
    else:
        "Unknown: " & $n

type
    Handle* = distinct pointer

    NodeUnion* {.union.} = object
        str* : cstring
        flag*: cint
        i64* : int64
        dbl* : float64
        list*: ptr NodeListObj
        ba*  : ptr ByteArrayObj

    NodeObj* = object
        data*  : NodeUnion
        format*: Format

    NodeListObj* = object
        count* : int32
        values*: ptr NodeObj
        keys*  : cStringArray

    ByteArrayObj* = object
        data*: pointer
        size*: csize_t

    EventPropertyObj* = object
        name*  : cstring
        format*: Format
        data*  : pointer

    EventLogMessageObj* = object
        prefix*   : cstring
        level*    : cstring
        text*     : cstring
        log_level*: LogLevel

    EventStartFileObj* = object
        playlist_entry_id*: int64

    EventEndFileObj* = object
        reason*               : EndFileReason
        error*                : ErrorCode
        playlist_entry_id*    : int64
        playlist_insert_id*   : int64
        playlist_insert_count*: int32

    EventClientMessageObj* = object
        arg_count*: int32
        args*     : cStringArray

    EventHookObj* = object
        name*: cstring
        id*  : uint64

    EventCommandObj* = object
        result: NodeObj

    EventObj* = object
        kind*          : EventKind
        error*         : ErrorCode
        reply_userdata*: uint64
        data*          : pointer

# Rendering
type
    RenderContext*  = distinct pointer
    RenderUpdateFn* = (pointer -> void)

    RenderParamKind* {.size: sizeof(cint).} = enum
        Invalid
        APIType
        OpenGLInitParams
        OpenGLFBO
        FlipY
        Depth
        ICCProfile
        AmbientLight
        X11Display
        WLDisplay
        AdvancedControl
        NextFrameInfo
        BlockForTargetTime
        SkipRendering
        DRMDisplay
        DRMDrawSurfaceSize
        DRMDisplayV2
        SWSize
        SWFormat
        SWStride
        SWPointer

    RenderParam* = object
        kind*: RenderParamKind
        data*: pointer

    RenderFrameInfoFlag* {.size: sizeof(uint64).} = enum
        Present    = 1 shl 0
        Redraw     = 1 shl 1
        Repeat     = 1 shl 2
        BlockVSync = 1 shl 3

    RenderFrameInfo* = object
        flags*      : RenderFrameInfoFlag
        target_time*: int64

    RenderUpdateFlag* {.size: sizeof(cint).} = enum
        None  = 0
        Frame = 1 shr 0

    OpenGLInitParamsObj* = object
        get_proc_address*    : (ctx: pointer, name: cstring) -> pointer
        get_proc_address_ctx*: pointer

    OpenGLFBOObj* = object
        fbo*         : int32
        w*, h*       : int32
        internal_fmt*: int32

    OpenGLDRMParamsObj* = object
        fd*                : int32
        crtc_id*           : int32
        connector_id*      : int32
        atomic_request_ptr*: ptr pointer # TODO: struct _drmModeAtomicReq **atomic_request_ptr;
        render_fd*         : int32

    OpenGLDRMParamsV2Obj* = object
        fd*                : int32
        crtc_id*           : int32
        connector_id*      : int32
        atomic_request_ptr*: ptr pointer # TODO: struct _drmModeAtomicReq **atomic_request_ptr;
        render_fd*         : int32

    OpenGLDRMDrawSurfaceSizeObj* = object
        width* : int32
        height*: int32

func render_param*(kind: RenderParamKind; data: pointer | ptr OpenGLInitParamsObj | ptr OpenGLFBOObj | cstring | ptr cint): RenderParam =
    result.kind = kind
    result.data = cast[pointer](data)

func opengl_fbo*(w, h: int; fbo = 0'i32; fmt = 0'i32): OpenGLFBOObj =
    OpenGLFBOObj(w: int32 w, h: int32 h, fbo: fbo, internal_fmt: fmt)

#[ -------------------------------------------------------------------- ]#

using
    ctx    : Handle
    ren_ctx: RenderContext
    udata  : uint64
    name   : cstring
    format : Format
    data   : pointer
    nodep  : ptr NodeObj

{.push dynlib: "".}
proc mpv_client_api_version*(): culong                         {.importc: "mpv_client_api_version".}
proc mpv_error_string*(error: ErrorCode): cstring              {.importc: "mpv_error_string"      .}
proc mpv_free*(data: pointer)                                  {.importc: "mpv_free"              .}
proc mpv_client_name*(ctx): cstring                            {.importc: "mpv_client_name"       .}
proc mpv_client_id*(ctx): int64                                {.importc: "mpv_client_id"         .}
proc mpv_create*(): Handle                                     {.importc: "mpv_create"            .}
proc mpv_initialize*(ctx): ErrorCode                           {.importc: "mpv_initialize"        .}
proc mpv_destroy*(ctx): ErrorCode                              {.importc: "mpv_destroy"           .}
proc mpv_terminate_destroy*(ctx)                               {.importc: "mpv_terminate_destroy" .}
proc mpv_create_client*(ctx; name): Handle                     {.importc: "mpv_create_client"     .}
proc mpv_create_weak_client*(ctx; name): Handle                {.importc: "mpv_weak_create_client".}
proc mpv_load_config_file*(ctx; file_name: cstring): ErrorCode {.importc: "mpv_load_config_file"  .}
proc mpv_free_node_contents*(node: ptr NodeObj)                {.importc: "mpv_free_node_contents".}

proc mpv_command*(ctx; args: cStringArray): ErrorCode                          {.importc: "mpv_command"            .}
proc mpv_command_node*(ctx; args, result: ptr NodeObj): ErrorCode              {.importc: "mpv_command_node"       .}
proc mpv_command_ret*(ctx; args: cStringArray; result: ptr NodeObj): ErrorCode {.importc: "mpv_command_ret"        .}
proc mpv_command_string*(ctx; args: cstring): ErrorCode                        {.importc: "mpv_command_string"     .}
proc mpv_command_async*(ctx; udata; args: cStringArray): ErrorCode             {.importc: "mpv_command_async"      .}
proc mpv_command_node_async*(ctx; udata; args: ptr NodeObj): ErrorCode         {.importc: "mpv_command_node_async" .}
proc mpv_abort_async_command*(ctx; udata)                                      {.importc: "mpv_abort_async_command".}

proc mpv_get_time_us*(ctx): int64                                 {.importc: "mpv_get_time_us"            .}
proc mpv_get_time_ns*(ctx): int64                                 {.importc: "mpv_get_time_ns"            .}
proc mpv_get_property*(ctx; name; format; data): ErrorCode        {.importc: "mpv_get_property"           .}
proc mpv_get_property_string*(ctx; name): cstring                 {.importc: "mpv_get_property_string"    .}
proc mpv_get_property_osd_string*(ctx; name): cstring             {.importc: "mpv_get_property_osd_string".}
proc mpv_get_property_async*(ctx; udata; name; format): ErrorCode {.importc: "mpv_get_property_async"     .}
proc mpv_del_property*(ctx; name): ErrorCode                      {.importc: "mpv_del_property"           .}
proc mpv_unobserve_property*(ctx; udata): ErrorCode               {.importc: "mpv_unobserve_property"     .}

proc mpv_set_option*(ctx; name; format; data): ErrorCode                {.importc: "mpv_set_option"         .}
proc mpv_set_option_string*(ctx; name; data: cstring): ErrorCode        {.importc: "mpv_set_option_string"  .}
proc mpv_set_property*(ctx; name; format; data): ErrorCode              {.importc: "mpv_set_property"       .}
proc mpv_set_property_string*(ctx; name; data: cstring): ErrorCode      {.importc: "mpv_set_property_string".}
proc mpv_set_property_async*(ctx; udata; name; format; data): ErrorCode {.importc: "mpv_set_property_async" .}
proc mpv_observe_property*(ctx; udata; name; format): ErrorCode         {.importc: "mpv_observe_property"   .}

proc mpv_event_name*(id: EventKind): cstring                            {.importc: "mpv_event_name"          .}
proc mpv_event_to_node*(dst: ptr NodeObj; src: ptr EventObj): ErrorCode {.importc: "mpv_event_to_node"       .}
proc mpv_request_event*(ctx; eid: EventKind; enable: cint): ErrorCode   {.importc: "mpv_request_event"       .}
proc mpv_request_log_messages*(ctx; min_lvl: cstring): ErrorCode        {.importc: "mpv_request_log_messages".}
proc mpv_wait_event*(ctx; timeout: cdouble): ptr EventObj               {.importc: "mpv_wait_event"          .}
proc mpv_wakeup*(ctx)                                                   {.importc: "mpv_wakeup"              .}
proc mpv_set_wakeup_callback*(ctx; cb: (pointer -> void); data)         {.importc: "mpv_set_wakeup_callback" .}
proc mpv_wait_async_requests*(ctx)                                      {.importc: "mpv_wait_async_requests" .}
proc mpv_hook_add*(ctx; udata; name; priority: cint): ErrorCode         {.importc: "mpv_hook_add"            .}
proc mpv_hook_continue*(ctx; id: uint64): ErrorCode                     {.importc: "mpv_hook_continue"       .}

proc mpv_render_context_create*(ren_ctx: ptr RenderContext; ctx; params: ptr RenderParam): ErrorCode {.importc: "mpv_render_context_create"             .}
proc mpv_render_context_set_parameter*(ren_ctx; param: RenderParam): ErrorCode                       {.importc: "mpv_render_context_set_parameter"      .}
proc mpv_render_context_get_info*(ren_ctx; param: RenderParam): ErrorCode                            {.importc: "mpv_render_context_get_info"           .}
proc mpv_render_context_set_update_callback*(ren_ctx; cb: RenderUpdateFn; cb_ctx: pointer)           {.importc: "mpv_render_context_set_update_callback".}
proc mpv_render_context_update*(ren_ctx): RenderUpdateFlag                                           {.importc: "mpv_render_context_update"             .}
proc mpv_render_context_render*(ren_ctx; params: ptr RenderParam): ErrorCode                         {.importc: "mpv_render_context_render"             .}
proc mpv_render_context_report_swap*(ren_ctx)                                                        {.importc: "mpv_render_context_report_swap"        .}
proc mpv_render_context_free*(ren_ctx)                                                               {.importc: "mpv_render_context_free"               .}
{.pop.}

{.push inline.}

template check_error(msg, body) =
    let code = body
    if code != Success:
        raise new_exception(MPVError, "[MPV] " & msg & " : " & $(mpv_error_string code))

func get_version*(): string =
    let v = mpv_client_api_version()
    try:
        &"{(v shr 16) and 0xFFFF}.{v and 0xFFFF}"
    except ValueError:
        "<Unknown>"

# proc mpv_set_property_string*(ctx; name; data: cstring): ErrorCode      {.importc: "mpv_set_property_string".}
proc set_property*(ctx: Handle; name, data: string) {.raises: MPVError.} =
    check_error "Failed to set property '" & name & "' to '" & data & "'":
        ctx.mpv_set_property_string(cstring name, cstring data)

proc client_name*(ctx): string = $(mpv_client_name ctx)
proc client_id*(ctx):   int    = mpv_client_id ctx
proc create*():         Handle = mpv_create()

proc init*(ctx: Handle) {.raises: MPVError.} =
    check_error "Failed to initialize":
        mpv_initialize ctx

proc destroy*(ctx: Handle) {.raises: MPVError.} =
    check_error "Failed to destroy context":
        mpv_destroy ctx

proc set_wakeup_cb*(ctx: Handle; cb: pointer -> void; data: pointer = nil) =
    ctx.mpv_set_wakeup_callback(cb, data)

proc command_async*(ctx: Handle; args: varargs[string]) {.raises: MPVError.} =
    let cargs = alloc_cstringarray args
    check_error "Failed to submit async command":
        ctx.mpv_command_async(0, cargs)

    dealloc_cstringarray cargs

iterator get_events*(ctx: Handle; timeout = 0.0): EventObj =
    var result: ptr EventObj
    while true:
        result = ctx.mpv_wait_event timeout
        if result.kind == None:
            break

        yield result[]

# Rendering #

proc create_render_context*(ctx: Handle; params: openArray[RenderParam]): RenderContext {.raises: MPVError.} =
    check_error "Failed to create render context":
        mpv_render_context_create(result.addr, ctx, params[0].addr)

proc set_param*(ren_ctx; param: RenderParam) {.raises: MPVError.} =
    check_error "Failed to set renderer parameter":
        ren_ctx.mpv_render_context_set_parameter param

proc update*(ren_ctx): RenderUpdateFlag =
    ren_ctx.mpv_render_context_update

proc render*(ren_ctx; params: varargs[RenderParam]) {.raises: MPVError.} =
    let cparams = @params & RenderParam()
    check_error "Failed to render with params":
        ren_ctx.mpv_render_context_render cparams[0].addr

proc set_update_cb*(ren_ctx; cb: RenderUpdateFn) =
    ren_ctx.mpv_render_context_set_update_callback(cb, nil)

proc report_swap*(ren_ctx) =
    ren_ctx.mpv_render_context_report_swap

proc destroy*(ren_ctx) =
    mpv_render_context_free ren_ctx

{.pop.}
