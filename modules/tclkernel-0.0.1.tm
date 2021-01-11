package require tmq
package require rl_json
package require sha256
package require jmsg

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
    tmq::serve pub [json get $conn iopub_port] iopub recv_iopub
    tmq::serve router [json get $conn shell_port] shell recv_shell
    tmq::serve router [json get $conn control_port] control  recv_control
    # tmq::serve router [json get $conn stdin_port] stdin recv_stdin

    # tmq::serve rep [json get $conn hb_port] hb recv_hb
    vwait forever
}

proc recv_shell {identity frames} {
     # shell needs an available iopub channel to
     # show status

     set jmsg [jmsg::new $frames]

     set msgtype [jmsg::msgtype $jmsg]
     puts "shell: $msgtype << $jmsg"
     handle_$msgtype $identity $jmsg
}


proc recv_control {identity frames} {
     # shell needs an available iopub channel to
     # show status

     set jmsg [jmsg::new $frames]

     set msgtype [jmsg::msgtype $jmsg]
     puts "control: $msgtype << $jmsg"
     handle_$msgtype $identity $jmsg
}

proc recv_iopub {zmsg} {
     puts "iopub: << [tmq::display $zmsg]"
}


proc handle_comm_info_request {identity jmsg} {
    # puts "Handling comm info request: $jmsg"
    variable modver
    set parent [dict get $jmsg header]
    dict with jmsg {
        set parent $header
        set username [json get $header username]
        set header  [jmsg::newheader $username comm_info_reply]
        set content {{"comms":{}}}
    }
    iopub send [jmsg::frames [jmsg::status $parent busy]]
    set frames [jmsg::frames $jmsg]
    shell send $identity $frames
    iopub send [jmsg::frames [jmsg::status $parent idle]]
}

proc handle_kernel_info_request {identity jmsg} {
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
    iopub send [jmsg::frames [jmsg::status $parent busy]]
    set frames [jmsg::frames $jmsg]
    shell send $identity $frames
    iopub send [jmsg::frames [jmsg::status $parent idle]]
}

proc handle_shutdown_request {identity jmsg} {
    set parent [dict get $jmsg header]
    dict with jmsg {
        set parent $header
        set username [json get $header username]
        set header  [jmsg::newheader $username shutdown_reply]
    }
    iopub send [jmsg::frames [jmsg::status $parent busy]]
    set frames [jmsg::frames $jmsg]
    control send $identity $frames
    # iopub send [jmsg::frames [jmsg::status $parent idle]]
    after 0 {
        puts ">>>>>>>>>>>>>>>>>>>>>>>>> Kernel stopped, pid: [pid] <<<<<<<<<<<<<<<<<<<<<<<<<"
        exit 0
    }
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
