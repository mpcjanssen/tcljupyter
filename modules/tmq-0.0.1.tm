namespace eval tmq {
	proc listen {type address callback} {
		puts "Listening for $address ($type)"
		socket -server [namespace code [list connection $type $address]] [dict get $address port]
	}
	proc connection {type address s ip port} {
		puts "Incoming connection from $s ($ip:$port) on $address ($type) "
	}
}