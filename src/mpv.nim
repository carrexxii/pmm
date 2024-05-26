from std/sugar import `->`

type CStringArray* = ptr UncheckedArray[cstring]

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

    EventID* {.size: sizeof(cint).} = enum
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
        keys*  : CStringArray

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
        args*     : CStringArray

    EventHookObj* = object
        name*: cstring
        id*  : uint64

    EventCommandObj* = object
        result: NodeObj

    EventObj* = object
        id*            : EventID
        error*         : ErrorCode
        reply_userdata*: uint64
        data*          : pointer

#[ -------------------------------------------------------------------- ]#

using
    ctx   : Handle
    udata : uint64
    name  : cstring
    format: Format
    data  : pointer
    nodep : ptr NodeObj

{.push dynlib: "".}
proc client_api_version*(): culong                    {.importc: "mpv_client_api_version".}
proc error_string*(error: cint): cstring              {.importc: "mpv_error_string"      .}
proc free*(data: pointer)                             {.importc: "mpv_free"              .}
proc client_name*(ctx): cstring                       {.importc: "mpv_client_name"       .}
proc client_id*(ctx): int64                           {.importc: "mpv_client_id"         .}
proc create*(): Handle                                {.importc: "mpv_create"            .}
proc initialize*(ctx): cint                           {.importc: "mpv_initialize"        .}
proc destroy*(ctx): cint                              {.importc: "mpv_destroy"           .}
proc terminate_destroy*(ctx)                          {.importc: "mpv_terminate_destroy" .}
proc create_client*(ctx; name): Handle                {.importc: "mpv_create_client"     .}
proc create_weak_client*(ctx; name): Handle           {.importc: "mpv_weak_create_client".}
proc load_config_file*(ctx; file_name: cstring): cint {.importc: "mpv_load_config_file"  .}
proc free_node_contents*(node: ptr NodeObj)           {.importc: "mpv_free_node_contents".}

proc command*(ctx; args: CStringArray): cint                          {.importc: "mpv_command"            .}
proc command_node*(ctx; args, result: ptr NodeObj): cint              {.importc: "mpv_command_node"       .}
proc command_ret*(ctx; args: CStringArray; result: ptr NodeObj): cint {.importc: "mpv_command_ret"        .}
proc command_string*(ctx; args: cstring): cint                        {.importc: "mpv_command_string"     .}
proc command_async*(ctx; udata; args: CStringArray): cint             {.importc: "mpv_command_async"      .}
proc command_node_async*(ctx; udata; args: ptr NodeObj): cint         {.importc: "mpv_command_node_async" .}
proc abort_async_command*(ctx; udata)                                 {.importc: "mpv_abort_async_command".}

proc get_time_us*(ctx): int64                            {.importc: "mpv_get_time_us"            .}
proc get_time_ns*(ctx): int64                            {.importc: "mpv_get_time_ns"            .}
proc get_property*(ctx; name; format; data): cint        {.importc: "mpv_get_property"           .}
proc get_property_string*(ctx; name): cstring            {.importc: "mpv_get_property_string"    .}
proc get_property_osd_string*(ctx; name): cstring        {.importc: "mpv_get_property_osd_string".}
proc get_property_async*(ctx; udata; name; format): cint {.importc: "mpv_get_property_async"     .}
proc del_property*(ctx; name): cint                      {.importc: "mpv_del_property"           .}
proc unobserve_property*(ctx; udata): cint               {.importc: "mpv_unobserve_property"     .}

proc set_option*(ctx; name; format; data): cint                {.importc: "mpv_set_option"         .}
proc set_option_string*(ctx; name; data: cstring): cint        {.importc: "mpv_set_option_string"  .}
proc set_property*(ctx; name; format; data): cint              {.importc: "mpv_set_property"       .}
proc set_property_string*(ctx; name; data: cstring): cint      {.importc: "mpv_set_property_string".}
proc set_property_async*(ctx; udata; name; format; data): cint {.importc: "mpv_set_property_async" .}
proc observe_property*(ctx; udata; name; format): cint         {.importc: "mpv_observe_property"   .}

proc event_name*(id: EventID): cstring                         {.importc: "mpv_event_name"          .}
proc event_to_node*(dst: ptr NodeObj; src: ptr EventObj): cint {.importc: "mpv_event_to_node"       .}
proc request_event*(ctx; eid: EventID; enable: cint): cint     {.importc: "mpv_request_event"       .}
proc request_log_messages*(ctx; min_lvl: cstring): cint        {.importc: "mpv_request_log_messages".}
proc wait_event*(ctx; timeout: cdouble): ptr EventObj          {.importc: "mpv_wait_event"          .}
proc wakeup*(ctx)                                              {.importc: "mpv_wakeup"              .}
proc set_wakeup_callback*(ctx; cb: (pointer -> void); data)    {.importc: "mpv_set_wakeup_callback" .}
proc wait_async_requests*(ctx)                                 {.importc: "mpv_wait_async_requests" .}
proc hook_add*(ctx; udata; name; priority: cint): cint         {.importc: "mpv_hook_add"            .}
proc hook_continue*(ctx; id: uint64): cint                     {.importc: "mpv_hook_continue"       .}
{.pop.}
