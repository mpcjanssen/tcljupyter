package require jmsg

set pipe {}

proc respond {jmsg} {
    variable ::pipe
    puts $pipe $jmsg
    flush $pipe
}

proc handle {jmsg} {
    set kernel_id [dict get $jmsg kernel_id]
    set parent [dict get $jmsg header]

    respond [jmsg::status $kernel_id $parent busy]
    
    respond [jmsg::status $kernel_id $parent idle]

}

proc recv {chan} {
    set jmsg [read $chan]
    set kernel_id [dict get $jmsg kernel_id]
    set parent [dict get $jmsg header]
    set msg_type [json get $parent msg_type]
    if {[info commands $msg_type] ne {}} {
	$msg_type $jmsg
    }
}

proc listen {from to} {
    set ::pipe $to
    fconfigure $from -blocking 0
    fconfigure $from -translation binary

    fileevent $from readable [list recv $from]
    vwait forever
}

