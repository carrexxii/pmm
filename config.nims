from std/strformat import `&`

const
    Bin = "./pmm"

    SrcDir = "./src"
    LibDir = "./lib"

    NSDLFlags = "-p:../nsdl -d:SDLDir=../nsdl"
    MPVFlags  = "--passL:-lmpv"

task run, "Run":
    exec &"nim c -r {NSDLFlags} {MPVFlags} -o:{Bin} {SrcDir}/main.nim"
