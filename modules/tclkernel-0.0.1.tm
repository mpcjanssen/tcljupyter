package require tmq
package require rl_json
package require sha256

namespace import rl_json::json

set script [file normalize [info script]]
set modfile [file root [file tail $script]]
lassign [split $modfile -] _ modver

proc connect {connection_file} {
    set f [open $connection_file]
    set conn [read $f]
    close $f
    set key [json get $conn key]
    puts $conn
    interp alias {} hmac {} sha2::hmac -hex -key $key
    tmq::serve router [json get $conn shell_port] shell recv_shell
    tmq::serve router [json get $conn control_port] control recv_control
    tmq::serve router [json get $conn stdin_port] stdin recv_stdin
    tmq::serve pub [json get $conn iopub_port] iopub recv_iopub
    tmq::serve rep [json get $conn hb_port] hb recv_hb
    vwait forever
}

proc checkhmac {hmac header parent metadata content} {
        set calc_hmac [hmac "$header$parent$metadata$content"]
        if {$calc_hmac ne $hmac} {
            return -code error "HMAC mismatch $calc_hmac : $hmac"
        }
}

proc recv_shell {zsocket frames} {
     puts "shell: $zsocket << [join [tmq::display $frames] \n]"
     set index [lsearch $frames "<IDS|MSG>"]
     if {$index != -1} {
	set frames [lrange $frames $index end]
     } else {
       return -code error "Can't find Jupyter delimiter"
     }
     lassign $frames delimiter hmac header parentheader metadata content
     checkhmac $hmac $header $parentheader $metadata $content
     $zsocket send

}


proc recv_control {zsocket zmsg} {
     puts "control: $zsocket << [tmq::display $zmsg]"
}

proc recv_iopub {zsocket zmsg} {
     puts "iopub: $zsocket << [tmq::display $zmsg]"
}

proc handle_info_request {zsocket jmsg} {
    # puts "Handling info request: $jmsg"
    variable modver
    set parent [dict get $jmsg header]
    dict with jmsg {
        set parent $header
        set username [json get $header username]
        set header  [jmsg::newheader $username kernel_info_reply]
        set version [info patchlevel]
	set banner [format "Tcl %s :: TclJupyter kernel %s \nProtocol v%s" \
			$version \
			$modver \
			"5.3"]
        set content [json template $::kernel_info]
    }
    respond shell $jmsg
}
set kernel_info { {
    "status" : "ok",
    "protocol_version": "5.3",
    "implementation": "tcljupyter",
    "implementation_version": "~S:modver",
    "language_info": {
        "name": "tcl",
        "version": "~S:version",
        "mimetype": "txt/x-tcl",
        "file_extension": ".tcl"
    },
    "banner" : "~S:banner"
}}
