package provide tclkernel 0.9.0
package require zmq
package require Thread
package require jmsg


set modver [package provide tclkernel]

set conn {}
set kernel_id [jmsg::newid]

array set ports {}
set sessions {}
set t {}

set context [zmq ctx_new]
zmq ctx_set $context -io_threads 2

proc connect {connection_file} {
    variable conn
    variable ports
    variable context
    set f [open $connection_file]
    set conn [read $f]
    set key [json get $conn key]
    interp alias {} hmac {}  sha2::hmac -hex -key $key 

    starthb
    set ports(iopub) [zmq socket $context XPUB]
    zmq setsockopt $ports(iopub) XPUB_VERBOSE 1
    zmq bind $ports(iopub) [address iopub]
    zmq readable $ports(iopub) on_iopub_subscription
    listen shell ROUTER
    listen control ROUTER
    listen stdin ROUTER
    start [pid]
}

proc on_iopub_subscription {} {
    variable ports
    set subscription [zmq recv $ports(iopub)]
    binary scan $subscription c subscribed
    if {$subscribed == 1} {
        respond [jmsg::status [json new] idle]
    }
}

proc respond_body {jmsg} {
    variable key
    variable ports
    variable kernel_id
    set port [dict get $jmsg port]
    dict with jmsg {
        json set header session $kernel_id
        set hmac [hmac [encoding convertto utf-8 "$header$parent$metadata$content"]] 
    }

    set zmsg [jmsg::znew $jmsg]
    set frames [lmap frame [lrange $zmsg 3 end] {encoding convertto utf-8 $frame}]
    set zmsg [lreplace $zmsg 3 end {*}$frames]
    # puts "$port [string repeat > 20]"
    # puts "RESPOND:\n[string range [join $zmsg \n] 0 1200]\n"
    zmq send_multipart $ports($port) $zmsg
}

proc respond {jmsg} {
    after 0 [list respond_body $jmsg]
}

proc on_recv {port} {
    variable ports
    variable t
    set to $t
    # puts -nonewline "Polling for message on $port"
    set res [zmq poll [list [list $ports($port) POLLIN]] 1]
    if {$res eq ""} {
	# puts "...none"
	return
    } {
	# puts "...handling"
    }
    set zmsg [zmq recv_multipart $ports($port)]
    # puts "\n\n\n\n$port [string repeat < 20]"
    # puts "REQ:\n[string range [join $zmsg \n] 0 1200]\n"
    set jmsg [jmsg::new [list $port {*}$zmsg]]
    set session [jmsg::session $jmsg]
    set type [jmsg::type $jmsg]
    if {$type eq "kernel_info_request"} {
        handle_info_request $jmsg
        return
    }
    if {$type eq "comm_info_request"} {
        handle_empty_reply $jmsg comm_info_reply comms [json new]
        return
    }
    if {$type eq "history_request"} {
        handle_empty_reply $jmsg history_reply history [json arr]
        return
    }
    if {$port eq "control"} {
        handle_control_request $jmsg
        return
    } 

    # puts ">>>>>>>>>>>>>>>>>>>>"
    # puts $jmsg

    thread::send -async $to [list dispatch_request $type $jmsg]
}

proc handle_empty_reply {jmsg reply_type content_key content_value} {
    dict with jmsg {
        set parent $header
        set username [json get $header username]
        set header [jmsg::newheader $username $reply_type]
        set content [json new]
        json nest content $content_key $content_value
    }
    respond $jmsg
}

proc start {pid} {
    variable t
    set t [thread::create]
    puts "Created thread $t for $pid"
    thread::send $t [list set master [thread::id]]
    thread::send $t [list set auto_path $::auto_path]
    thread::send $t [list tcl::tm::path add {*}[tcl::tm::path list]]
    thread::send $t {
        package require sessionclient
        session_init
    }
}

proc starthb {} {
    variable context
    variable ports
    set ports(hb) [zmq socket $context REP]
    zmq bind $ports(hb) [address hb]
    zmq readable $ports(hb) on_hb
}

proc on_hb {} {
    variable ports
    set message [zmq recv_multipart $ports(hb)]
    zmq send_multipart $ports(hb) $message
}



proc listen {port type} {
    variable ports
    variable context
    set ports($port) [zmq socket $context $type]
    zmq bind $ports($port) [address $port]
    zmq readable $ports($port) [list on_recv $port]
    # bit of a nasty hack because readable callback is a single
    # command without arguments
}

proc address {port} {
    variable conn
    set address [json get $conn transport]://
    append address [json get $conn ip]:
    append address [json get $conn ${port}_port]
    return $address
}

proc handle_control_request {jmsg} {
    set shutdown 0
    variable t
    set ph [dict get $jmsg header]
    set ps [jmsg::session $jmsg]
    set msg_type [json get $ph msg_type]
    set reply_type {}
    switch -exact $msg_type {
        shutdown_request {
            set shutdown 1
            set reply_type shutdown_reply
        }
        interrupt_request {
            set reply_type interrupt_reply
            puts "Interrupting kernel [pid]"
            thread::cancel  $t
        }
    }
    dict with jmsg {
        set parent $ph
        json set header msg_type $reply_type
    }
    respond $jmsg
    if {$shutdown} {
        puts "Shutting down kernel [pid]"
        after 0 exit
    }
}

proc handle_info_request {jmsg} {
    variable modver
    set parent [dict get $jmsg header]
    respond [jmsg::status $parent busy]
    dict with jmsg {
        set parent $header
        set username [json get $header username]
        set header  [jmsg::newheader $username kernel_info_reply] 
        set version [info patchlevel]

        set content $::kernel_info
    }
    respond $jmsg
    after 100 [list respond [jmsg::status $parent idle]]
}

set version [info patchlevel]
set language_info [json new name Tcl version $version mimetype txt/x-tcl file_extension .tcl]
set kernel_info [json new status ok protocol_version 5.4 implementation tcljupyter implementation_version $modver]
set banner [format "Tcl %s :: TclJupyter kernel %s \nProtocol v%s" \
			$version \
			$modver \
			"5.4"]

json nest kernel_info language_info $language_info
json set kernel_info banner $banner

puts $$$$$$$$$$$$$$$$$$$$$$$$
puts $kernel_info
puts $$$$$$$$$$$$$$$$$$$$$$$$



