     package require uuid

     array set peers {}

     set clients {}
        proc start {port alias} {
             socket -server [namespace code [list connection $alias]] $port
             set ::alias $alias
        }
        
        
        proc connection {alias socket remoteip remoteport} {
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
	        fileevent $socket readable $coroname
             # set peers($dentity) $socket

        }
        proc send {identiy zmsg} {
             variable type
             puts "Sending zmsg on $alias (router) id: $identity"
        }

          proc recv {socket alias} {
             variable clients
             yield
             puts "$alias:  ROUTER handshake"
             lassign [tmq::readzmsg $socket] zmsgtype zmsg
             puts "$alias: <<< [tmq::display $zmsg]"
             tmq::sendzmsg $socket cmd [list \x05READY\x0bSocket-Type[tmq::len32 ROUTER]ROUTER]
             yield
             while 1 {
                 lassign [tmq::readzmsg $socket] zmsgtype zmsg
                 if {$zmsg eq {}} {
                  # No message close coro
                  puts "WARN: No message on $alias closing callbacks"
                  return
                 }
                 if {$zmsgtype eq "msg"} {
                    on_recv $zmsg
                 }
                 yield
             }

        }

        proc on_cmd {cmd identity args} {
             puts "router cmd $args"
             switch -exact $cmd {
                  send {

                  }
             }
        }