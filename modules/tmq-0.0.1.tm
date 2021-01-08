namespace eval tmq {
        # namespace for connection handlers and socket aliases
        namespace eval coro {}
        namespace eval socket {}
        set socket_id 0

        proc socketcmd {zsocket socket cmd args} {
             puts "Handling socket command $zsocket $cmd $args"
        }

        proc serve {type port alias callback} {
             variable socket_id
             puts "Serving $type on $port"
             set zsocket [namespace current]::[incr socket_id]
             socket -server [namespace code [list connection $type $zsocket $alias $callback]] $port

             return $zsocket
        }
        proc connection {type zsocket alias callback socket remoteip remoteport} {
             puts "Incoming connection on $alias: $zsocket ($type)"
             puts "Negotiating version"
             set greeting [binary decode hex [join [subst {
		ff00000000000000017f0300
		[binary encode hex NULL]
		[string repeat 00 16]
		00
		[string repeat 00 31]
	        }] ""]]
             fconfigure $socket -blocking 1 -encoding binary
             puts "$zsocket >>> [display $greeting]"
             puts -nonewline $socket $greeting
             flush $socket
             set remotegreeting [read $socket 64]
             puts "$zsocket <<< [display $remotegreeting]"
             set coroname ::tmq::coro::$socket
             coroutine $coroname recv_$type $zsocket $socket $alias $callback
	     fileevent $socket readable $coroname
             interp alias {} $zsocket {} ::tmq::socketcmd $zsocket $socket

        }
        # coroutine to handle incoming router connections
        proc recv_router {zsocket socket alias callback} {
             yield
             puts "$alias: $zsocket ROUTER handshake"
             lassign [readzmsg $socket] zmsgtype zmsg
             puts "$alias: $zsocket <<< [display $zmsg]"
             sendzmsg $socket cmd [list \x05READY\x0bSocket-Type[len32 ROUTER]ROUTER]
             yield
             while 1 {
                 lassign [readzmsg $socket] zmsgtype zmsg
                 if {$zmsgtype eq "msg"} {
                    {*}$callback $zsocket $zmsg
                 }
                 yield
             }

        }
        # coroutine to handle incoming router connections
        proc recv_pub {zsocket socket alias callback} {
             yield
             puts "$alias: $zsocket PUB handshake"
             lassign [readzmsg $socket] zmsgtype zmsg
             puts "$alias: $zsocket <<< [display $zmsg]"
             sendzmsg $socket cmd [list \x05READY\x0bSocket-Type[len32 PUB]PUB\x08Identity[len32 ""]]
             yield
             while 1 {
                 if {$zmsgtype eq "msg"} {
                    {*}$callback $zsocket $zmsg
                 }
                 yield
             }

        }

        proc zframe {ztype frame} {
             set length [string length $frame]
             if {$length > 255} {
	        set format W
	     } else {
		set format c
	     }
             set lengthbytes [binary format $format $length]
             switch -exact $ztype-$format {
                    cmd-W {return \x06$lengthbytes$frame}
                    cmd-c {return \x04$lengthbytes$frame}
                    msg-more-W {return \x03$lengthbytes$frame}
                    msg-more-c {return \x01$lengthbytes$frame}
                    msg-last-W {return \x02$lengthbytes$frame}
                    msg-last-c {return \x00$lengthbytes$frame}


                    default {
                       return -code error "Invalid message prefix $ztype-$more"
                    }

             }




        }

        proc sendzmsg {socket ztype frames} {
             		# on the wire format is UTF-8
		if {$ztype eq "cmd"} {
                   if {[llength $frames]!=1} {
                      return -error "zmq commands can only have one frame"
                   }
                   set zframe [zframe cmd [lindex $frames 0]]
                   puts "$socket >>> [display $zframe]"
                   puts -nonewline $socket $zframe
                   flush $socket
                   return
                }

		foreach frame [lrange $frames 0 end-1] {
                        set zframe [zframe msg-more $frame]
                        puts "$socket >>> [display $zframe]"
			puts -nonewline $socket $zframe
		}
		set frame [lindex $zmsg end]
                set zframe [zframe msg-last $frame]
                puts "$socket >>> [display $zframe]"
		puts -nonewline $socket $zframe
                flush $socket
        }

        proc readzmsg {socket} {
        set more 1
			set frames {}
			while {$more} {
				set prefix [read $socket 1]
				if {[eof $socket]} {
					puts "ERROR: Socket $socket closed"
					fileevent $socket readable {}
					return
				}

				switch -exact $prefix {
					\x00 {
						set zmsg_type msg
						set more 0
						set size short
					}
					\x01 {
						set zmsg_type msg
						set more 1
						set size short
					}
					\x02 {
						set zmsg_type msg
						set more 0
						set size long
					}
					\x03 {
						set zmsg_type msg
						set more 1
						set size long
					}
					\x04 {
						set zmsg_type cmd
						set more 0
						set size short
					}
					\x06 {
						set zmsg_type cmd
						set more 0
						set size long
					}
					default {
						close $socket
						return -code error "ERROR: Unknown frame start [display $prefix 0]"
					}
				}
				if {$size eq "short"} {
					set length [read $socket 1]
					binary scan $length c bytelength
					set bytelength [expr { $bytelength & 0xff }]
				} {
					set length [read $socket 8]
					binary scan $length W  bytelength
				}
				set frame [read $socket $bytelength]
				lappend frames $frame
			}
                        return [list $zmsg_type $frames]
                        }



	proc display {data {showascii 1}} {
		set decoded {}

		foreach x [split $data ""] {
			binary scan $x c d 
				if {$d < 32 || $d > 126 || !$showascii}  {
					append decoded \\x[binary encode hex $x]
				} {
					append decoded $x
				}

		}
		return $decoded
	}
        proc zlen {str} {
		if {[string length $str] < 256} {
			return \x04[len8 $str]
		} else {
			return \x06[len32 $str]
		}
	}

	proc len32 {str} {
			return [binary format I [string length $str]]
	}
	proc len8 {str} {
			return [binary format c [string length $str]]
	}


}
