proc recv {chan} {
	puts ++++++++++++->$::pipe
	puts [read $chan]
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

