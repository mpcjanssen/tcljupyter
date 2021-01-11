     package require uuid

     set initialstart 1
     set queue {}

     set peers {}
        proc start {port alias} {
             socket -server [namespace code [list connection $alias]] $port
             set ::alias $alias
        }
        
        
        proc connection {alias socket remoteip remoteport} {
		fconfigure $socket -encoding binary -translation binary -blocking 1
             variable peers
             variable queue
             puts "Incoming connection on $alias: (PUB)"
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
             puts "$alias: PUB handshake"
             lassign [tmq::readzmsg $socket] zmsgtype zmsg
             tmq::sendzmsg $socket cmd [list \x05READY\x0bSocket-Type[tmq::len32 PUB]PUB\x08Identity[tmq::len32 ""]]
             lappend peers $socket

        }

        proc on_cmd {cmd args} {
             cmd-$cmd {*}$args
        }

         proc cmd-send {zmsg} {
             variable peers

             puts "Sending zmsg on (pub)"

             set initialstart 0
             foreach peer $peers {
               if {[catch {tmq::sendzmsg $peer msg [list {} {*}$zmsg]} result]} {
                    puts =============$result$::errorInfo
                    set peers [lsearch -all -inline -not $peers $peer]
               }
             }
        }
        
