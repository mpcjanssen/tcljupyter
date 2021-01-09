package require zmq
package require rl_json
package require jmsg

namespace import rl_json::json
set to {}
set execph {}



proc busy {header} {
    iopub [list busy $header]

}

proc idle {header} {
     iopub [list idle $header]
}

proc handle_messages {key} {
    set zmsg [zmsg recv zsocket]
    set jmsg [jmsg::new $key $zmsg]
    set msg_type [jmsg::msg_type $jmsg]
    puts "$::me <<< $msg_type"
    switch -exact $msg_type {
           kernel_info_request {
              kernel_info_reply $jmsg
           }
           execute_request {
              execute_reply $jmsg
           }
           default {
                   puts "$::me WARN: $msg_type unsupported"
           }
    }
    update idletasks
    after 0 [list handle_messages $key]
}

proc start {address key iopubthread} {
zmq context context
interp alias {} iopub {} thread::send  $iopubthread
zmq socket zsocket context ROUTER
zsocket bind $address
set ::key $key

set ::me "shell([pid])"
startto   [pid]
handle_messages $key
}



proc startto {pid} {
    variable to
    set t [thread::create thread::wait]
    set to $t
    puts "Created thread $t for $pid"
    thread::send $t [list set master [thread::id]]
    thread::send $t [list set auto_path $::auto_path]
    thread::send $t [list tcl::tm::path add {*}[tcl::tm::path list]]

}

proc sessionerror {args} {
     variable exec_ph
     puts "ERROR: $args"
}

proc execute_reply {jmsg} {
    variable to
    variable exec_ph
    set exec_ph [jmsg::header $jmsg]
    set master [thread::id]
    thread::errorproc sessionerror
         # wrap command in a catch to capture and handle interrupt messages
    thread::send  -async $to [list execute $jmsg]
}


proc kernel_info_reply {jmsg} {
    set orig_header [jmsg::header $jmsg]
    busy $orig_header
    dict with jmsg {
        set parent $header
        set username [json get $header username]
        set header  [jmsg::newheader $username kernel_info_reply]
        set version [info patchlevel]
	set banner [format "Tcl %s :: TclJupyter kernel 0.1 \nProtocol v%s" \
			$version \
			"5.3"]
        set content [json template $::kernel_info]
    }
    puts "$::me >>> kernel_info_reply"
    jmsg::send $jmsg $::key zsocket
    idle $orig_header
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



