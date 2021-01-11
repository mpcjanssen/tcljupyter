     package require uuid

     array set peers {}
     set initialstart 1
     set clients {}
        proc start {port alias} {
             socket -server [namespace code [list connection $alias]] $port
             set ::alias $alias
        }
        
        
        proc connection {alias socket remoteip remoteport} {
		fconfigure $socket -encoding binary -translation binary -blocking 1
             variable peers
             puts "Incoming connection on $alias: (ROUTER)"
             puts "Negotiating version"
             set greeting [binary decode hex [join [subst {
		ff00000000000000017f0300
		[binary encode hex NULL]
		[string repeat 00 16]
		00
		[string repeat 00 31]
	        }] ""]]
             fconfigure $socket -blocking 1 -encoding binary
             puts "$alias >>> [tmq::display $greeting]"
             puts -nonewline $socket $greeting
             flush $socket
             set remotegreeting [read $socket 64]
             puts "$alias <<< [tmq::display $remotegreeting]"
             set coroname ::coro_$socket
             coroutine $coroname recv $socket $alias 
             puts "$alias:  ROUTER handshake"
             lassign [tmq::readzmsg $socket] zmsgtype zmsg
             # puts "$alias: <<< [tmq::display [lindex $zmsg 0]]"
             tmq::sendzmsg $socket cmd [list \x05READY\x0bSocket-Type[tmq::len32 ROUTER]ROUTER]
	     if {$::initialstart} {  
		     after 1500 [list fileevent $socket readable $coroname]
		     set ::initialstart 0
	     } else {
	        fileevent $socket readable $coroname
	     }
             set identity [uuid::uuid generate]
             set peers(id-$identity) $socket
             set peers(sock-$socket) $identity

        }


          proc recv {socket alias} {
             variable peers
             yield
             while 1 {
                 lassign [tmq::readzmsg $socket] zmsgtype zmsg
                 if {$zmsg eq {}} {
                  # No message close coro
                  return
                 }
                 if {$zmsgtype eq "msg"} {
                    try {
                         on_recv $peers(sock-$socket) $zmsg
                    } on error result {
                         puts "ERROR in router $alias on_recv callback\n$result"
                    }
                 }
                 yield
             }

        }

        proc on_cmd {cmd args} {
             cmd-$cmd {*}$args
        }

         proc cmd-send {identity zmsg} {
             variable peers
             puts "Sending zmsg on (router) id: $identity"
             tmq::sendzmsg $peers(id-$identity) msg $zmsg
        }

        
