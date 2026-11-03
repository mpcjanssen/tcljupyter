package provide tclkernel 0.9.0
package require zmq
package require Thread
package require jmsg

namespace eval tclkernel {
    variable modver [package provide tclkernel]
    variable conn {}
    variable kernel_id [jmsg::newid]
    variable ports
    array set ports {}
    # Id of the worker thread that evaluates user code
    variable worker {}

    variable context [zmq ctx_new]
    zmq ctx_set $context -io_threads 2

    variable version [info patchlevel]
    variable kernel_info [json new status ok protocol_version 5.4 \
        implementation tcljupyter implementation_version $modver]
    json nest kernel_info language_info [json new name Tcl version $version \
        mimetype txt/x-tcl file_extension .tcl]
    json set kernel_info banner [format "Tcl %s :: TclJupyter kernel %s \nProtocol v%s" \
        $version $modver 5.4]

    # Write a trace line to stderr when TCLJUPYTER_DEBUG is set
    proc debug {text} {
        if {[info exists ::env(TCLJUPYTER_DEBUG)]} {
            puts stderr $text
        }
    }

    proc connect {connection_file} {
        debug "kernel_info: $::tclkernel::kernel_info"

        variable conn
        variable ports
        variable context
        set f [open $connection_file]
        set conn [read $f]
        close $f
        set key [json get $conn key]
        interp alias {} hmac {} sha2::hmac -hex -key $key

        starthb
        set ports(iopub) [zmq socket $context XPUB]
        zmq setsockopt $ports(iopub) XPUB_VERBOSE 1
        zmq bind $ports(iopub) [address iopub]
        zmq readable $ports(iopub) [namespace code on_iopub_subscription]
        listen shell ROUTER
        listen control ROUTER
        listen stdin ROUTER
        start [pid]
    }

    proc address {port} {
        variable conn
        return [json get $conn transport]://[json get $conn ip]:[json get $conn ${port}_port]
    }

    proc starthb {} {
        variable context
        variable ports
        set ports(hb) [zmq socket $context REP]
        zmq bind $ports(hb) [address hb]
        zmq readable $ports(hb) [namespace code on_hb]
    }

    proc on_hb {} {
        variable ports
        zmq send_multipart $ports(hb) [zmq recv_multipart $ports(hb)]
    }

    proc listen {port type} {
        variable ports
        variable context
        set ports($port) [zmq socket $context $type]
        zmq bind $ports($port) [address $port]
        zmq readable $ports($port) [namespace code [list on_recv $port]]
    }

    proc on_iopub_subscription {} {
        variable ports
        set subscription [zmq recv $ports(iopub)]
        binary scan $subscription c subscribed
        if {$subscribed == 1} {
            respond [jmsg::status [json new] idle]
        }
    }

    # Start the worker thread that runs the sessionclient and user code
    proc start {pid} {
        variable worker
        set worker [thread::create]
        puts "Created thread $worker for $pid"
        thread::send $worker [list set auto_path $::auto_path]
        thread::send $worker [list tcl::tm::path add {*}[tcl::tm::path list]]
        thread::send $worker [list apply {{master} {
            package require sessionclient
            sessionclient::init $master
        }} [thread::id]]
    }

    proc respond_body {jmsg} {
        variable ports
        variable kernel_id
        set port [dict get $jmsg port]
        dict with jmsg {
            json set header session $kernel_id
            set hmac [hmac [encoding convertto utf-8 "$header$parent$metadata$content"]]
        }

        set zmsg [jmsg::znew $jmsg]
        debug "$port [string repeat > 20]\nRESPOND:\n[string range [join $zmsg \n] 0 1200]"
        set frames [lmap frame [lrange $zmsg 3 end] {encoding convertto utf-8 $frame}]
        set zmsg [lreplace $zmsg 3 end {*}$frames]
        zmq send_multipart $ports($port) $zmsg
    }

    # Called from the worker thread as well, so it must not block
    proc respond {jmsg} {
        after 0 [namespace code [list respond_body $jmsg]]
    }

    proc on_recv {port} {
        variable ports
        variable worker
        if {[zmq poll [list [list $ports($port) POLLIN]] 1] eq ""} {
            return
        }
        set zmsg [zmq recv_multipart $ports($port)]
        debug "$port [string repeat < 20]\nREQ:\n[string range [join $zmsg \n] 0 1200]"
        set jmsg [jmsg::new [list $port {*}$zmsg]]

        switch -exact [jmsg::type $jmsg] {
            kernel_info_request {
                handle_info_request $jmsg
            }
            comm_info_request {
                handle_empty_reply $jmsg comm_info_reply comms [json new]
            }
            history_request {
                handle_empty_reply $jmsg history_reply history [json arr]
            }
            default {
                if {$port eq "control"} {
                    handle_control_request $jmsg
                } else {
                    # Handled by the worker, which reports errors (and interrupts)
                    thread::send -async $worker [list sessionclient::dispatch_request \
                        [jmsg::type $jmsg] $jmsg]
                }
            }
        }
    }

    proc handle_empty_reply {jmsg reply_type content_key content_value} {
        set content [json new]
        json nest content $content_key $content_value
        respond [jmsg::reply $jmsg $reply_type $content]
    }

    proc handle_info_request {jmsg} {
        variable kernel_info
        set parent [dict get $jmsg header]
        respond [jmsg::status $parent busy]
        respond [jmsg::reply $jmsg kernel_info_reply $kernel_info]
        after 100 [namespace code [list respond [jmsg::status $parent idle]]]
    }

    proc handle_control_request {jmsg} {
        variable worker
        switch -exact [jmsg::type $jmsg] {
            shutdown_request {
                respond [jmsg::reply $jmsg shutdown_reply [dict get $jmsg content]]
                puts "Shutting down kernel [pid]"
                after 0 exit
            }
            interrupt_request {
                puts "Interrupting kernel [pid]"
                thread::cancel $worker
                respond [jmsg::reply $jmsg interrupt_reply [dict get $jmsg content]]
            }
        }
    }
}
