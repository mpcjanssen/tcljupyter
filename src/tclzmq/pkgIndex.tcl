if {![package vsatisfies [package provide Tcl] 8.5]} {return}
package ifneeded zmq 4.0.1 [list ::apply {dir {
    source [file join $dir critcl-rt.tcl]
    set path [file join $dir [::critcl::runtime::MapPlatform]]
    set ext [info sharedlibextension]
    set lib [file join $path "zmq$ext"]
    load $lib Zmq
    ::critcl::runtime::Fetch $dir zmq_helper_1.tcl
    package provide zmq 4.0.1
}} $dir]
