package require zmq
package require Thread
package require rl_json
package require sha256

namespace import ::rl_json::json

set conn {}
set key {}

proc connect {connection_file} {
    variable conn
    variable key
    set f [open $connection_file]
    set conn [read $f]
    set key [json get $conn key]
    puts $conn
    zmq context context
    listen shell ROUTER
    listen control ROUTER
    listen stdin ROUTER
    starthb
    zmq socket ::ports::iopub context PUB
    ::ports::iopub bind [address iopub]
    startsession abcd
}


proc pub {msg} {
    
}



proc on_recv {port} {
   parray ::sessions
    set socket ::ports::$port
    puts "$port [string repeat < 20]"
    set msg [zmsg recv $socket]
    set buffers [lassign $msg uuid delimiter hmac header parentheader metadata content]
    puts "uuid:    $uuid"
    puts "delim:   $delimiter"
    puts "hmac:    $hmac"
    puts "header:  $header"  
    puts "parent:  $parentheader"
    puts "meta:    $metadata"
    puts "content: $content"
    set tosocket $::sessions(abcd)
    puts -nonewline $tosocket $msg
    flush $tosocket    
}

proc incoming {chan session} {
	puts $session
	puts [read $chan]

	
}

proc startsession {session} {
    set t [thread::create]
    lassign [chan pipe] fromSession toMaster
    lassign [chan pipe] fromMaster toSession
    fileevent $fromSession readable [list incoming $fromSession $session]
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
    set socket ::ports::$port
    zmq socket $socket context $type
    $socket bind [address $port]
    # bit of a nasty hack because readable callback is a single
    # command without arguments
    interp alias {} on_recv_$port {} on_recv $port
    $socket readable on_recv_$port
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
