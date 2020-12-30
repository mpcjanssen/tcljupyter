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

	set greeting [join [subst {
		ff00000000000000017f03
		00
		[binary encode hex NULL]
		[string repeat 00 15]
		01
		[string repeat 00 31]
	}] ""]
	set ready [join [subst {
		04
		29
		05
		[binary encode hex READY]
		0B
		[binary encode hex Socket-Type]
	
	}] ""]

	puts \f

	proc listen {type address callback} {
		puts "Listening for $address ($type)"
		socket -server [namespace code [list connection $type $address]] [dict get $address port]
	}

	proc connection {type address s ip port} {
		puts "Incoming connection from $s ($ip:$port) on $address ($type) "
		set context $address


		coroutine ::tmq_$s handle [string toupper $type] $s
		fileevent $s readable ::tmq_$s
	}

	proc handle {type s} {
	    variable greeting
	    variable ready
		puts "Incoming $type connection"
		fconfigure $s -blocking 1 -encoding binary
		# Negotiate version
		pputs $s [string range [binary decode hex $greeting] 0 10]
		flush $s
		set remote_greeting [read $s 11]
	    # Send rest of greeting
		pputs $s [string range [binary decode hex $greeting] 11 end]
		flush $s
		append remote_greeting [read $s [expr {64-11}]]

		puts "Remote greeting [display $remote_greeting]"
		# Send the ready command
		set msg \x05READY\x0bSocket-Type[len32 $type]$type\x08Identity[len32 ""]
		pputs $s \x04[len32 $msg]
		pputs $s $msg
		flush $s
				


		
		fconfigure $s -blocking 0 -encoding binary
		yield
		while {1} {
			puts [display [read $s]]
				if {[eof $s]} {close $s ; return}
			yield
		}
	}
	

	proc len32 {str} {
			return [binary format I [string length $str]]
	}



}

