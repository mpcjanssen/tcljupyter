namespace eval tmq {
	array set channels {}
	array set queue {}
	proc display {data {showascii 0}} {
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


	proc sendchannel {name bytes} {
		variable queue
		lappend queue($name) $bytes
		variable channels
		if {[catch {
			set channel $channels($name)
			if {[eof $channel]} {
				# Remote closed
				puts "WARN: Remote $channel ($name) was closed"
				close $channel
				return 0
			}
			while {[llength $queue($name)] > 0} {
				set rest [lassign $queue($name) msg]
				puts -nonewline $channel $msg
				flush $channel
				if {[eof $channel]} break
				set queue($name) $rest
 
			}


		
		} result]} {
			puts "ERROR: could not send to channel $name\n$result"
			
		}
	}

	proc send {name zmsg} {
		# on the wire format is UTF-8
		puts ">>>> $name"
		set zmsg [lmap m $zmsg {encoding convertto utf-8 $m}]

		foreach msg [lrange $zmsg 0 end-1] {
			set length [string length $msg]
			if {$length > 255} {
				set format W
				set prefix \x03
			} else {
				set format c
				set prefix \x01	
			}
			set length_bytes [binary format $format $length]
			# puts [display [string range $prefix$length_bytes$msg 0 200]]
			sendchannel $name $prefix$length_bytes$msg
		}
		set msg [lindex $zmsg end]
		set length [string length $msg]
		if {$length > 255} {
			set format W
			set prefix \x02
		} else {
			set format c
			set prefix \x00	
		}
		set length_bytes [binary format $format $length]
		# puts [display [string range $prefix$length_bytes$msg 0 200]]
		sendchannel $name $prefix$length_bytes$msg
	}

	set greeting [binary decode hex [join [subst {
		ff00000000000000017f
		03
		00
		[binary encode hex NULL]
		[string repeat 00 16]
		00
		[string repeat 00 31]
	}] ""]]

	if {[string length $greeting] != 64} {
		error "Invalid greeting constant [string length $greeting] <> 64"
	}

	proc listen {name type address callback} {
		puts "Listening for $address ($name:$type)"
		socket -server [namespace code [list connection $name $type $address]] [dict get $address port]
	}

	proc connection {name type address s ip port} {
		variable channels
		puts "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@\nIncoming connection from $s ($ip:$port) on $address ($type) "
		set channels($name) $s
		negotiate $name $port [string toupper $type] $s
		coroutine ::tmq_$s handle $name $port [string toupper $type] $s
		fileevent $s readable ::tmq_$s

	}

	proc negotiate {name port type channel} {
	    variable greeting
	    variable ready
		fconfigure $channel -blocking 1 -encoding binary -translation binary
		puts "Incoming $type connection"
		# Negotiate version
		sendchannel $name [string range $greeting 0 10]
		set remote_greeting [read $channel 11]
		# puts "Remote greeting [display $remote_greeting]"
	    # Send rest of greeting
		sendchannel $name [string range $greeting 11 end]
		append remote_greeting [read $channel [expr {64-11}]]


		

	}

	proc handle {name port type channel} {
		yield
		variable channels

		while {1} {
			# readable read the complete message
			set more 1
			set frames {}		
			while {$more} {
				set prefix [read $channel 1]
				if {[eof $channel]} {
					puts "ERROR: Channel $channel closed" 
					fileevent $channel readable {}
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
						close $channel
						return -code error "ERROR: Unknown frame start [display $prefix 0]" 
					}
				}
				if {$size eq "short"} {
					set length [read $channel 1]
					binary scan $length c bytelength
					set bytelength [expr { $bytelength & 0xff }] 
				} {
					set length [read $channel 8]  
					binary scan $length W  bytelength
				}
				set frame [read $channel $bytelength]
				# puts "INFO: << [display $prefix$length$frame] 1]"
				#puts "INFO: Frame length $bytelength"
				lappend frames $frame
			}
			puts "<<<< $name ($channel:$port:$zmsg_type)"
			set channels($name) $channel
			flush stdout
			if {$zmsg_type eq "msg"} {
				# is this a Jupyter msg?
				set index [lsearch $frames "<IDS|MSG>"]
				if {$index != -1} {
					set jmsg [jmsg::new $channel $name $type {*}[lrange $frames $index end]]
					on_recv $jmsg
				} {
					puts "WARN: Ignoring non-Jupyter zmq msg\n[display [join $frames \n] 1]\n"	
				}
			} else {
				# TODO: ignore zmq commands and pubsub for now
		# Send the ready command
		set first [lindex $frames 0]
		if {[string range $first 0 5] eq "\x05READY"} {
		set msg \x05READY\x0bSocket-Type[len32 $type]$type
		if {$type ne "ROUTER"} {
			append msg \x08Identity[len32 ""]
		} 
		set zmsg [zlen $msg]$msg
		# puts ">>>> $name ($port:$type)\n[display $zmsg]"
		sendchannel $name $zmsg
		} {
				puts "WARN: Ignoring zmq command\n[display [join $frames \n] 1]\n"
			} }
			yield
		}	
	}
	
	proc handle_command data {
		return {1 {}}

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

