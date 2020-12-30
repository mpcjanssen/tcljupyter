interp alias {} pputs {} puts -nonewline

namespace eval tmq {
	proc display {data} {
		set decoded {}

		foreach x [split $data ""] {
    	binary scan $x c d 
    	if {$d > 31 && $d < 127} {append decoded $x} else {append decoded \\x[binary encode hex $x]}
		
	}
	return $decoded
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


	puts \f

	proc listen {name type address callback} {
		puts "Listening for $address ($name:$type)"
		socket -server [namespace code [list connection $name $type $address]] [dict get $address port]
	}

	proc connection {name type address s ip port} {
		puts "Incoming connection from $s ($ip:$port) on $address ($type) "
		set context $address


		coroutine ::tmq_$s handle $name $port [string toupper $type] $s
		fileevent $s readable ::tmq_$s
	}

	proc handle {name port type s} {
	    variable greeting
	    variable ready

		puts "Incoming $type connection"
		fconfigure $s -blocking 1 -encoding binary
		# Negotiate version
		pputs $s [string range $greeting 0 10]
		flush $s
		set remote_greeting [read $s 11]
	    # Send rest of greeting
		pputs $s [string range $greeting 11 end]
		flush $s
		append remote_greeting [read $s [expr {64-11}]]

		puts "Remote greeting [display $remote_greeting]"
		# Send the ready command

		set msg \x05READY\x0bSocket-Type[len32 $type]$type
		if {$type eq "ROUTER"} {
			append msg \x08Identity[len32 ""]
		}
		set zmsg [zlen $msg]$msg
		puts ">>>> $name ($port:$type)\n[display $zmsg]"
		pputs $s $zmsg
		flush $s
			
		fconfigure $s -blocking 0 -encoding binary
		yield
		set data {}
		set frames {}
		while {1} {
			set part [read $s]
			append data $part
			puts "<<<< $name ($port:$type)\n[display $part]"
			if {[eof $s]} {close $s ; return}
			set frame_read 1
		    while {$frame_read && $data ne {}} {
				lassign [read_frame $data] frame data last
				if {$frame eq {}} {
					puts "No more frames to read for now"
					set frame_read 0
				} {
					lappend frames $frame
					if {$last} {
						catch {
						puts "Handling:\n [join $frames \n]"
						set jmsg [jmsg::new [list $name {*}$frames]]
						puts $jmsg
						} result
						puts $result
						set frames {}

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
			binary scan $data cI _ length
			set lenght [expr { $length & 0xffffffff }]
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

