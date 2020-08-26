namespace eval tmq {
    proc listen {type address callback} {
	puts "Listening for $address ($type)"
	socket -server [namespace code [list connection $type $address]] [dict get $address port]
    }

proc connection {type address s ip port} {
    puts "Incoming connection from $s ($ip:$port) on $address ($type) "
    set context $address
    dict set context type $type
    fconfigure $s -blocking 0 -encoding binary
    send_header $s    
    fileevent $s readable [namespace code [list readdata $s $context]]
}
proc readdata {s ctx} {
    set data [read $s]
    if {[eof $s]} {
	puts "Closed $s ($ctx)"
	close $s
	return
    }
    set frame [parseframe $data]
    puts $ctx:$frame
    
}

proc send_header {s} {
    puts -nonewline $s [binary decode hex ff00000000000000017f03004e554c4c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000]


    flush $s
}


proc parseframe {data} {
    puts [binary encode hex $data]
    # ignore greeting
    set frame {}
    set data [string range $data 10 end]
    binary scan $data cc  version_major version_minor
    set data [string range $data 2 end]
    binary scan $data A20 mechanism
    set data [string range $data 20 end]
    binary scan $data c asserver
    set data [string range $data 1 end]
    dict set frame version major [expr {$version_major & 0xFF}]
    dict set frame version minor [expr {$version_minor & 0xFF}]
    dict set frame mechanism $mechanism
    dict set frame asserver [expr {$asserver & 0xFF}]
    
    dict set frame unparsed [binary encode hex [string range $data 31 end]] 
    return $frame
}
}
