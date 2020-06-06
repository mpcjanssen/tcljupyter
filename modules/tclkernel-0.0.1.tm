package require zmq
package require Thread
package require jmsg

set conn {}
set key {}
variable ports
variable sessions

proc connect {connection_file} {
    variable conn
    variable key
    variable ports
    set f [open $connection_file]
    set conn [read $f]
    set key [json get $conn key]
    puts $conn
    zmq context context
    listen shell ROUTER
    listen control ROUTER
    listen stdin ROUTER
    starthb
    set ports(iopub) [zmq socket context PUB]
    $ports(iopub) bind [address iopub]
}

proc pub {session state} {
    puts ">> IOopub $session $state"
}

proc respond {jmsg} {
    variable key
    variable ports
    set port [dict get $jmsg port]
    set session [jmsg::session $jmsg]
    set jmsg [jmsg::updatehmac $jmsg $key]
    set zmsg [jmsg::znew $jmsg]
    puts "RESPOND: $zmsg"
    foreach msg [lrange $zmsg 0 end-1] {
	$ports($port) sendmore $msg
    }
    $ports($port) send [lindex $zmsg end]
    pub $session idle
}



proc on_recv {port} {
    variable ports
    set zmsg [zmsg recv $ports($port)]
    puts "REQ: $zmsg"
    set jmsg [jmsg::new [list $port {*}$zmsg]]
    set session [jmsg::session $jmsg]
    set type [jmsg::type $jmsg]
    puts "$port $type $session [string repeat < 20]"
    pub $session busy
    if {![info exists ::sessions($session)]} {
	startsession $session
    }
    if {$type eq "kernel_info_request"} {
	handle_info_request $jmsg
	return
    }
    return
    set tosocket  $::sessions($session)
    puts -nonewline $tosocket  $jmsg
    flush $tosocket    
}

proc incoming {chan} {
    set jmsg [read $chan]
    respond $jmsg
}

proc startsession {session} {
    set t [thread::create]
    lassign [chan pipe] fromSession toMaster
    lassign [chan pipe] fromMaster toSession
    fileevent $fromSession readable [list incoming $fromSession]
    fconfigure $fromSession -blocking 0
    set ::sessions($session) $toSession
    thread::send $t [list set auto_path $::auto_path]
    thread::send $t [list tcl::tm::path add {*}[tcl::tm::path list]]
    thread::send $t {package require sessionclient}
    thread::transfer $t $fromMaster
    thread::transfer $t $toMaster
    thread::send -async $t [list listen $fromMaster $toMaster]
}

proc starthb {} {
    set t [thread::create]
    thread::send $t -async [list set auto_path $::auto_path]
    thread::send $t -async {package require zmq}
    thread::send $t -async {zmq context context}
    thread::send $t -async [list zmq socket zsocket context REP]
    thread::send $t -async [list zsocket bind [address hb]]
    thread::send $t -async [puts [list start [address hb]]]
    thread::send $t -async {while {1} {
	zmq device FORWARDER zsocket zsocket
    }}
}

proc listen {port type} {
    variable ports
    set ports($port) [zmq socket context $type]
    $ports($port) bind [address $port]
    # bit of a nasty hack because readable callback is a single
    # command without arguments
    interp alias {} on_recv_$port {} on_recv $port
    $ports($port) readable on_recv_$port
}

proc address {port} {
    variable conn
    set address [json get $conn transport]://
    append address [json get $conn ip]:
    append address [json get $conn ${port}_port]
    return $address
}


proc handle_info_request {jmsg} {
    dict with jmsg {
	set parent $header
	json set header msg_type kernel_info_reply
	set content $::kernel_info
    }
    respond $jmsg
    
}

set kernel_info { {
    "status" : "ok",
    "protocol_version": "5.3",
    "implementation": "tcljupyter",
    "implementation_version": "0.0.1",
    "language_info": {
        "name": "tcl",
        "version": "8.6.10",
        "mimetype": "txt/x-tcl",
        "file_extension": ".tcl"
    }
}}
