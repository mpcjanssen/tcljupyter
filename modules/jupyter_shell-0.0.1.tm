package require zmq
package require rl_json
package require jmsg

namespace import rl_json::json


proc busy {jmsg} {
    iopub [list busy [jmsg::header $jmsg]]

}

proc idle {jmsg} {
     iopub [list idle [jmsg::header $jmsg]]
}

proc start {address key iopubthread} {
zmq context context
interp alias {} iopub {} thread::send  $iopubthread
zmq socket zsocket context ROUTER
zsocket bind $address
set ::key $key

set ::me "shell([pid])"

while 1 {
    set zmsg [zmsg recv zsocket]
    set jmsg [jmsg::new $key $zmsg]
    busy $jmsg
    set msg_type [jmsg::msg_type $jmsg]
    puts "$::me <<< $msg_type"
    switch -exact $msg_type {
           kernel_info_request {

              kernel_info_reply $jmsg
           }
           default {
                   puts "$::me WARN: $msg_type unsupported"
           }
    }
    idle $jmsg


}
}

proc kernel_info_reply {jmsg} {

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



