namespace eval ::zmq {
    namespace export *
    namespace ensemble create

    variable monitorid 0

    proc monitor_callback {socket callback} {
	if {[catch {$socket recv_monitor_event} d]} {
	    error $d
	} else {
	    uplevel #0 [list $callback $d]
	}
    }

    proc monitor {context sock callback {events ALL}} {
	variable monitorid
	set id monitor[incr monitorid]
	$sock monitor "inproc://$id" $events
	set socket [zmq socket $id $context PAIR]
	$socket connect "inproc://$id"
	$socket readable [list ::zmq::monitor_callback $socket $callback]
	return $id
    }

    proc have_libsodium {} {
	zmq context ctx
	zmq socket s ctx PUB
	if {[catch {s getsockopt CURVE_SERVER} msg]} {
	    set have_libsodium 0
	} else {
	    set have_libsodium 1
	}
	s close
	ctx term
	return $have_libsodium
    }
}

namespace eval ::zmsg {
    namespace export *
    namespace ensemble create

    proc recv {socket} {
	set rt [list]
	lappend rt [$socket recv]
	while {[$socket getsockopt RCVMORE]} {
	    lappend rt [$socket recv]
	}
	return $rt
    }

    proc send {socket msgl} {
	foreach m [lrange $msgl 0 end-1] {
	    $socket sendmore $m
	}
	$socket send [lindex $msgl end]
    }

    proc unwrap {msglnm} {
	upvar $msglnm msgl
	set data ""
	if {[llength $msgl]} {
	    set msgl [lassign $msgl data]
	}
	if {[llength $msgl] && [string length [lindex $msgl 0]] == 0} {
	    set msgl [lassign $msgl empty]
	}
	return $data
    }

    proc wrap {msgl data} {
	return [list $data "" {*}$msgl]
    }

    proc push {msgl data} {
	return [list $data {*}$msgl]
    }

    proc pop {msglnm} {
	upvar $msglnm msgl
	set msgl [lassign $msgl first]
	return $first
    }

    proc add {msgl data} {
	return [list {*}$msgl $data]
    }

    proc dump {msgl} {
	set rt [list]
	if {[llength $msgl]} {
	    set m .#[pid]
	    foreach data $msgl {
		zmq message $m -data $data
		lappend rt [$m dump]
		$m close
	    }
	} else {
	    lappend rt "NULL"
	}
	return $rt
    }
}
