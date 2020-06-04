package require zmq
package require Thread
package require rl_json

namespace eval tclkernel {
  variable conn
  namespace import ::rl_json::json
  proc connect {connection_file} {
    variable conn
    set f [open $connection_file]
    set conn [read $f]
    puts $conn
    listen_hb
    listen shell ROUTER
    listen control ROUTER
    listen stdin ROUTER
    listen iopub PUB
    puts ok
  }

  proc listen_hb {} {
    set t [thread::create]
    thread::send $t -async [list set auto_path $::auto_path]
    thread::send $t -async "package require zmq"
    thread::send $t -async {zmq context context}
    thread::send $t -async [list zmq socket zsocket context REP]
    thread::send $t -async [list zsocket bind [address hb]]
    thread::send $t -async [puts [list start [address hb]]]
    thread::send $t -async {while {1} {zmq device FORWARDER zsocket zsocker}}
    puts "here"

  }

  proc listen {portname type} {
    set t [thread::create]
    thread::send -async  $t [list set auto_path $::auto_path]
    thread::send  -async $t "package require zmq"
    thread::send -async $t  {zmq context context}
    thread::send -async $t  [list zmq socket zsocket context $type]
    thread::send -async $t  [list zsocket bind [address $portname]]
    thread::send -async $t  [puts [list start [address $portname]]]
    thread::send -async $t  {while {1} {puts [zsocket recv]}}
    thread::send -async $t  [list puts stdout $portname]
    thread::send -async $t  {puts end}
    puts "here"

  }

  proc handle_hb {} {
    puts [hb recv]
  }

  proc address {portname} {
    variable conn
    set address [json get $conn transport]://
    append address [json get $conn ip]:
    append address [json get $conn ${portname}_port]
    return $address

  }

}

