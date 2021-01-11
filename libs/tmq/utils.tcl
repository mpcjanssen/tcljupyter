namespace eval tmq {
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
                   # puts "$socket >>> [display $zframe]"
                   puts -nonewline $socket $zframe
                   flush $socket
                   return
                }

		foreach frame [lrange $frames 0 end-1] {
                        set zframe [zframe msg-more $frame]
                        # puts "$socket >>> [display $zframe]"
			puts -nonewline $socket $zframe
		}
		set frame [lindex $frames end]
                set zframe [zframe msg-last $frame]
                # puts "$socket >>> [display $zframe]"
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
                    if {[eof $socket]} {
					puts "ERROR: Socket $socket closed"
					fileevent $socket readable {}
					return 
				}
				set frame [read $socket $bytelength]
                    if {[eof $socket]} {
					puts "ERROR: Socket $socket closed"
					fileevent $socket readable {}
					return 
				}
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