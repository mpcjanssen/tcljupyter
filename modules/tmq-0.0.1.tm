namespace eval tmq {
	proc display {data} {
		set decoded {}

		foreach x [split $data ""] {
    	binary scan $x c d 
    	if {$d > 31 && $d < 127} {append decoded $x} else {append decoded \\x[binary encode hex $x]}
		
	}
	return $decoded
	}

	proc send {name zmsg} {
		variable ${name}_socket
		set channel [set ${name}_socket]
		puts "Sending on $name zmq port ($channel)"
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
			puts [display $prefix$length_bytes$msg]
			pputs $channel $prefix$length_bytes$msg
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
		puts [display $prefix$length_bytes$msg]
		pputs $channel $prefix$length_bytes$msg
		flush $channel
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
		puts "Incoming connection from $s ($ip:$port) on $address ($type) "
		dict with address {
			variable ${channel}_socket 
			set ${channel}_socket $s
		}
		set context $address


		coroutine ::tmq_$s handle $name $port [string toupper $type] $s
		fileevent $s readable ::tmq_$s
	}

	proc handle {name port type channel} {
	    variable greeting
	    variable ready

		puts "Incoming $type connection"
		fconfigure $channel -blocking 1 -encoding binary
		# Negotiate version
		pputs $channel [string range $greeting 0 10]
		flush $channel
		set remote_greeting [read $channel 11]
	    # Send rest of greeting
		pputs $channel [string range $greeting 11 end]
		flush $channel
		append remote_greeting [read $channel [expr {64-11}]]

		puts "Remote greeting [display $remote_greeting]"
		# Send the ready command

		set msg \x05READY\x0bSocket-Type[len32 $type]$type
		if {$type eq "ROUTER"} {
			append msg \x08Identity[len32 ""]
		}
		set zmsg [zlen $msg]$msg
		puts ">>>> $name ($port:$type)\n[display $zmsg]"
		pputs $channel $zmsg
		flush $channel 
			
		fconfigure $channel  -blocking 0 -encoding binary
		yield
		set data {}
		set frames {}
		set zmq_type {}
		while {1} {
			set part [read $channel]
			append data $part
			puts "<<<< $name ($channel:$port:$type)\n[display $part]"
			if {[eof $channel]} {close $channel ; return}
			set frame_read 1
		    while {$frame_read && $data ne {}} {
					if {$data ne {} && $zmq_type eq {}} {
					set first [string index $data 0]
					if {$first in [list \x04 \x06]} {
						set zmq_type cmd
					} else {
						set zmq_type msg
					}
				}
				lassign [read_frame $data] frame data last
				if {$frame eq {}} {
					puts "No more frames to read for now"
					set frame_read 0
				} {
					lappend frames $frame
					if {$last} {
						if {[catch {
							puts "Handling $zmq_type:\n[join $frames \n]"
							flush stdout
							if {$zmq_type eq "msg"} {
								set jmsg [jmsg::new $channel $name $type {*}$frames]
								on_recv $jmsg
							} else {
								# TODO: ignore commands for now
							}
						}]} {
							puts "ERROR handling\n\n[join $frames \n]"
						}
						set frames {}
						set zmq_type {}

					}
				}

			}
			yield
		}
	}
	
	proc read_frame {data} {
		# puts [display $data]
		set first [string index $data 0]
		if {$first in [list \x00 \x01 \x04]} {
			if {[string length $data] < 2} {return [list {} $data 0]}
			binary scan $data cc _ length
			set length [expr { $length & 0xff }]
			set rest [string range $data 2 end]
		} elseif {$first in [list \x02 \x03 \x06]} {
			if {[string length $data] < 5} {return [list {} $data 0]}
			binary scan $data cW _ length
			set rest [string range $data 5 end]
		} else {
			return -code error "Unknown start of frame [display $data]"
		}
		# puts "$length < [string length $rest] ?"
		if {[string length $rest] < $length} {
			return [list {} $data 0]
		}
		set frame [string range $rest 0 $length-1]
		# puts "Got: [display $frame]"
		set data [string range $rest $length end]
		# puts "Last frame? [display $first]"
		if {$first ni [list \x01 \x03]} {
			# puts "Yes last"
			# last frame
			return [list $frame $data 1]
		} else {
			return [list $frame $data 0]
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

