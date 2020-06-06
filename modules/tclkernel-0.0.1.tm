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
    variable ports
    set port [dict get $jmsg port]
    set session [jmsg::session $jmsg]
    set zmsg [jmsg::znew $jmsg]
    puts "RESPOND: $zmsg"
    foreach msg [lrange $zmsg 0 end-1] {
	$ports($port) sendmore $msg
    }
    $ports($port) send [lindex $msg end]
    pub $session idle
}



proc on_recv {port} {
    variable ports
    puts "$port [string repeat < 20]"
    set jmsg [jmsg::new [list $port {*}[zmsg recv $ports($port)]]]
    puts $jmsg
    set session [jmsg::session $jmsg]
    puts $session
    pub $session busy
    if {![info exists ::sessions($session)]} {
	startsession $session
    }
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
    puts [tcl::tm::path list]
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


set kernel_info { {
    "status" : "ok",
    "protocol_version": "5.3",
    "implementation": "tcljupyter",
    "implementation_version": "0.0.1",
    "language_info": {
        "name": "tcl",
        "version": "8.6.10",
        "mimetype": "txt/tcl",
        "file_extension": ".tcl"
    }
}}
