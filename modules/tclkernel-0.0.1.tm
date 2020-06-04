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
}


proc pub {msg} {
    
}

proc on_recv {port} {
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


    puts "$port [string repeat > 20]"
    variable key
    set content "{}"
    set hmac [sha2::hmac -hex -key $key  "$header$parentheader$metadata$content"]
    $socket sendmore $uuid
    $socket sendmore $delimiter
    $socket sendmore $hmac
    $socket sendmore $header
    $socket sendmore $parentheader
    $socket sendmore $metadata
    $socket send $content
    
    
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

