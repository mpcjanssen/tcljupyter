namespace eval tmq {
    proc listen {type address callback} {
	puts "Listening for $address ($type)"
	socket -server [namespace code [list connection $type $address]] [dict get $address port]
    }

proc connection {type address s ip port} {
    puts "Incoming connection from $s ($ip:$port) on $address ($type) "
    set context $address
    
   
    coroutine ::tmq_$s handle [string tolower $type] $s
    fileevent $s readable ::tmq_$s
}

proc handle {type s} {
    puts "Incoming $type connection"
    fconfigure $s -blocking 0 -encoding binary
    puts -nonewline $s [binary decode hex ff00000000000000017f03004e554c4c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000]
    flush $s
    yield
    while {1} {
        puts [binary encode hex [read $s]]
        if {[eof $s]} {close $s ; return}
        yield
    }
}


}

