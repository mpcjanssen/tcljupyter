proc recv {chan} {
	puts ++++++++++++->$::pipe
	set msg [read $chan]
    set buffers [lassign $msg port uuid delimiter hmac header parentheader metadata content]
    puts "port:    $port"
    puts "uuid:    $uuid"
    puts "delim:   $delimiter"
    puts "hmac:    $hmac"
    puts "header:  $header"  
    puts "parent:  $parentheader"
    puts "meta:    $metadata"
    puts "content: $content"
	puts $::pipe "test"
        flush $::pipe
	puts ok


	
}
proc listen {from to} {
   set ::pipe $to
   fconfigure $from -blocking 0
   fconfigure $from -translation binary

   fileevent $from readable [list recv $from]
   vwait forever
}

