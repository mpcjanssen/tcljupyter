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
  puts "$port [string repeat > 20]"
  puts "RESPOND:\n[string range [join $zmsg \n] 0 1200]\n"
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
  puts "REQ:\n[string range [join $zmsg \n] 0 1200]\n"
  set jmsg [jmsg::new [list $port $kernel_id {*}$zmsg]]
  set session [jmsg::session $jmsg]
  set type [jmsg::type $jmsg]
  if {$type eq "kernel_info_request"} {
    handle_info_request $jmsg
    return
  }
  if {$port eq "control"} {
    handle_control_request $jmsg
    return
  } 
  if {![info exists ::sessions($session)]} {
    startsession $session
  }

  #    puts ">>>>>>>>>>>>>>>>>>>>"
  #    puts $jmsg
  set to  $::sessions($session)
  thread::send -async $to [list $type $jmsg]
}


proc startsession {session} {
  set t [thread::create]
  puts "Created thread $t"
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
  set shutdown 0
  set kernel_id [dict get $jmsg kernel_id]
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
      foreach {session tid} [array get ::sessions] {
        puts "Interrupting session $session"
        thread::cancel $tid "<<interrupted>>"
      }

    }
  }
  dict with jmsg {
    set parent $ph
    json set header msg_type $reply_type
  }
  respond $jmsg
  if {$shutdown} {
    puts "Shutting down kernel"
    after 0 exit
  }
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
