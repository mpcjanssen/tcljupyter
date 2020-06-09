package require zmq
package require Thread
package require jmsg

set conn {}
set key {}
set kernel_id [jmsg::newid]
variable ports
variable sessions

proc connect {connection_file} {
  variable conn
  variable key
  variable ports
  set f [open $connection_file]
  set conn [read $f]
  set key [json get $conn key]
  zmq context context
  listen shell ROUTER
  listen control ROUTER
  listen stdin ROUTER
  starthb
  set ports(iopub) [zmq socket context PUB]
  $ports(iopub) bind [address iopub]
}

proc respond {jmsg} {
  variable key
  variable ports
  set port [dict get $jmsg port]
  dict with jmsg {
    set hmac [sha2::hmac -hex -key $key  "$header$parent$metadata$content"] 
  }

  set zmsg [jmsg::znew $jmsg]
  # puts "$port [string repeat > 20]"
  puts "RESPOND: [string range [join $zmsg \n] 0 1200]\n"
  foreach msg [lrange $zmsg 0 end-1] {
    $ports($port) sendmore $msg
  }
  $ports($port) send [lindex $zmsg end]

}



proc on_recv {port} {
  variable ports
  variable kernel_id
  set zmsg [zmsg recv $ports($port)]
  puts "\n\n\n\n$port [string repeat < 20]"
  puts "REQ: [string range [join $zmsg \n] 0 1200]\n"
  set jmsg [jmsg::new [list $port $kernel_id {*}$zmsg]]
  set session [jmsg::session $jmsg]
  set type [jmsg::type $jmsg]
  if {![info exists ::sessions($session)]} {
    startsession $session
  }
  if {$type eq "kernel_info_request"} {
    handle_info_request $jmsg
    return
  }
  if {$port eq "control"} {
    handle_control_request $jmsg
    return
  }
  #    puts ">>>>>>>>>>>>>>>>>>>>"
  #    puts $jmsg
  set to  $::sessions($session)
  thread::send -async $to [list recv $jmsg]
}


proc startsession {session} {
  set t [thread::create]
  set ::sessions($session) $t
  thread::send $t [list set master [thread::id]]
  thread::send $t [list set auto_path $::auto_path]
  thread::send $t [list tcl::tm::path add {*}[tcl::tm::path list]]
  thread::send $t {package require sessionclient}
  thread::send -async $t listen
}

proc starthb {} {
  set t [thread::create]
  thread::send $t -async [list set auto_path $::auto_path]
  thread::send $t -async {package require zmq}
  thread::send $t -async {zmq context context}
  thread::send $t -async [list zmq socket zsocket context REP]
  thread::send $t -async [list zsocket bind [address hb]]
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


proc handle_control_request {jmsg} {
  set kernel_id [dict get $jmsg kernel_id]
  set parent [dict get $jmsg header]
  set msg_type [json get $parent msg_type]
  respond [jmsg::status $kernel_id $parent busy]
  dict with jmsg {
    switch -exact $msg_type {
      shutdown_request {
        after 0 {
          exit
        }
        json set header msg_type shutdown_reply
      }
    }
  }
  respond $jmsg
  respond [jmsg::status $kernel_id $parent idle]
}

proc handle_info_request {jmsg} {
  set kernel_id [dict get $jmsg kernel_id]
  set parent [dict get $jmsg header]
  respond [jmsg::status $kernel_id $parent busy]
  dict with jmsg {
    set parent $header
    set username [json get $header username]
    set header  [jmsg::newheader $kernel_id $username kernel_info_reply] 
    set version [info patchlevel]
    set content [json template $::kernel_info]
  }
  respond $jmsg
  respond [jmsg::status $kernel_id $parent idle]
}
set kernel_info { {
  "status" : "ok",
  "protocol_version": "5.3",
  "implementation": "tcljupyter",
  "implementation_version": "0.0.1",
  "language_info": {
    "name": "tcl",
    "version": "~S:version",
    "mimetype": "txt/x-tcl",
    "file_extension": ".tcl"
  }
}}
