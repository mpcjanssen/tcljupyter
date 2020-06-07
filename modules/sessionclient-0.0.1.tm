package require jmsg

proc recv {chan} {
    set jmsg [read $chan]
    dict with jmsg {
	puts "port:    $port"
	puts "uuid:    $uuid"
	puts "delim:   $delimiter"
	puts "hmac:    $hmac"
	puts "header:  $header"  
	puts "parent:  $parent"
	puts "meta:    $metadata"
	puts "content: $content"
    }
    return
    puts $::pipe $jmsg
    
    flush $::pipe
}
proc listen {from to} {
    set ::pipe $to
    fconfigure $from -blocking 0
    fconfigure $from -translation binary

    fileevent $from readable [list recv $from]
    vwait forever
}

