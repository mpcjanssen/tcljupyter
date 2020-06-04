package require zmq
package require rl_json

namespace eval tclkernel {
  variable conn
  namespace import ::rl_json::json
  proc connect {connection_file} {
    variable conn
    set f [open $connection_file]
    set conn [read $f]
    puts $conn
    zmq context context
    listen hb REQ
    listen shell ROUTER
    listen control ROUTER
    puts [address hb]
  }

  proc listen {portname type} {
    set addr [address $portname]
    zmq socket $portname context $type
    $portname bind $addr
    $portname readable [namespace code handle_$portname]
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

