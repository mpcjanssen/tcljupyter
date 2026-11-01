# Socket-type specific routing: ROUTER (RFC 28), PUB/SUB/XPUB/XSUB (RFC 29).
# Other types use the engine's generic load-balance / fair-queue routing.

proc ::zmq::TypeName {socket} {
    variable sockets
    zmtp::type_name [dict get $sockets($socket) type]
}

proc ::zmq::Subscribed {subs data} {
    foreach topic $subs {
        if {[string equal -length [string length $topic] $topic $data]} {
            return 1
        }
    }
    return 0
}

# Legacy (ZMTP 3.0) subscription message, accepted by all ZMTP 3.x peers.
proc ::zmq::SubscriptionFrame {subscribe topic} {
    zmtp::frame [binary format c [expr {$subscribe ? 1 : 0}]]$topic
}

# Called once a pipe completed its handshake.
proc ::zmq::PipeReady {conn} {
    variable conns
    variable sockets
    variable const
    set socket [dict get $conns($conn) socket]
    switch -- [TypeName $socket] {
        ROUTER {
            set props [dict get $conns($conn) props]
            set id [expr {[dict exists $props Identity] ? [dict get $props Identity] : ""}]
            if {$id ne "" && [dict exists $sockets($socket) routes $id]} {
                if {![dict get $sockets($socket) options $const(ZMQ_ROUTER_HANDOVER)]} {
                    Detach $conn
                    return
                }
                Detach [dict get $sockets($socket) routes $id]
            }
            if {$id eq ""} {
                set n [dict get $sockets($socket) nextRid]
                dict set sockets($socket) nextRid [expr {($n + 1) & 0xFFFFFFFF}]
                set id [binary format cI 0 $n]
            }
            dict set conns($conn) routingId $id
            dict set conns($conn) props Routing-Id $id
            dict set sockets($socket) routes $id $conn
        }
        SUB - XSUB {
            foreach topic [dict get $sockets($socket) subscriptions] {
                if {![Write $conn [SubscriptionFrame 1 $topic]]} {
                    return
                }
            }
        }
    }
}

# Called after a pipe was detached; c is its final state.
proc ::zmq::PipeGone {socket conn c} {
    variable sockets
    set id [dict get $c routingId]
    if {$id ne "" && [dict exists $sockets($socket) routes $id]
            && [dict get $sockets($socket) routes $id] eq $conn} {
        dict unset sockets($socket) routes $id
    }
    if {[TypeName $socket] eq "XPUB"} {
        foreach topic [dict get $c subs] {
            XpubCount $socket 0 $topic
        }
    }
}

# Decide what to do with a complete incoming message. Returns 1 to queue it
# for the application (frames may be rewritten), 0 to drop it.
proc ::zmq::RouteIncoming {conn framesVar} {
    variable conns
    variable sockets
    upvar 1 $framesVar frames
    set socket [dict get $conns($conn) socket]
    switch -- [TypeName $socket] {
        ROUTER {
            set frames [linsert $frames 0 [dict get $conns($conn) routingId]]
        }
        PUB - XPUB {
            set first [lindex $frames 0]
            if {[llength $frames] == 1 && [string index $first 0] in [list \x00 \x01]} {
                PeerSubscription $conn [expr {[string index $first 0] eq "\x01"}] \
                    [string range $first 1 end]
            }
            return 0
        }
        SUB - XSUB {
            return [Subscribed [dict get $sockets($socket) subscriptions] [lindex $frames 0]]
        }
    }
    return 1
}

# SUBSCRIBE/CANCEL from a SUB/XSUB peer, either as command or legacy message.
proc ::zmq::PeerSubscription {conn subscribe topic} {
    variable conns
    set socket [dict get $conns($conn) socket]
    set type [TypeName $socket]
    if {$type ni {PUB XPUB}} {
        return
    }
    set subs [dict get $conns($conn) subs]
    if {$subscribe} {
        lappend subs $topic
    } else {
        set idx [lsearch -exact $subs $topic]
        if {$idx < 0} {
            return
        }
        set subs [lreplace $subs $idx $idx]
    }
    dict set conns($conn) subs $subs
    if {$type eq "XPUB"} {
        XpubCount $socket $subscribe $topic
    }
}

# Track subscription counts on XPUB and report changes to the application.
proc ::zmq::XpubCount {socket subscribe topic} {
    variable sockets
    variable const
    set counts [dict get $sockets($socket) subcount]
    set n [expr {[dict exists $counts $topic] ? [dict get $counts $topic] : 0}]
    set n [expr {$subscribe ? $n + 1 : max(0, $n - 1)}]
    if {$n > 0} {
        dict set counts $topic $n
    } else {
        dict unset counts $topic
    }
    dict set sockets($socket) subcount $counts
    set verbose [dict get $sockets($socket) options $const(ZMQ_XPUB_VERBOSE)]
    if {($subscribe && ($n == 1 || $verbose)) || (!$subscribe && $n == 0)} {
        Enqueue $socket [list [binary format c $subscribe]$topic] {}
    }
}

# Send a SUB socket's subscription change to all connected publishers.
proc ::zmq::SendSubscription {socket subscribe topic} {
    variable sockets
    variable conns
    foreach conn [dict get $sockets($socket) pipes] {
        if {[info exists conns($conn)] && [dict get $conns($conn) state] eq "ready"} {
            Write $conn [SubscriptionFrame $subscribe $topic]
        }
    }
}

# ROUTER: the first frame names the destination peer and is not sent.
proc ::zmq::RouterSend {socket data more} {
    variable sockets
    variable const
    set conn [dict get $sockets($socket) outconn]
    if {$conn eq ""} {
        if {[dict exists $sockets($socket) routes $data]} {
            set conn [dict get $sockets($socket) routes $data]
        } elseif {[dict get $sockets($socket) options $const(ZMQ_ROUTER_MANDATORY)]} {
            Fail EHOSTUNREACH
        } else {
            set conn dropped
        }
    } elseif {$conn ne "dropped" && ![Write $conn [zmtp::frame $data $more]]} {
        set conn dropped
    }
    dict set sockets($socket) outconn [expr {$more ? $conn : ""}]
}

# PUB/XPUB: send to every peer subscribed to the first frame. XSUB: send to all.
# Never blocks; without subscribers the message is dropped.
proc ::zmq::FanoutSend {socket data more} {
    variable sockets
    variable conns
    set type [TypeName $socket]
    if {![dict get $sockets($socket) fanoutMore]} {
        set targets {}
        foreach conn [dict get $sockets($socket) pipes] {
            if {[dict get $conns($conn) state] eq "ready"
                    && ($type eq "XSUB" || [Subscribed [dict get $conns($conn) subs] $data])} {
                lappend targets $conn
            }
        }
        dict set sockets($socket) fanout $targets
        if {$type eq "XSUB" && !$more && [string index $data 0] in [list \x00 \x01]} {
            XsubTrack $socket [expr {[string index $data 0] eq "\x01"}] [string range $data 1 end]
        }
    }
    foreach conn [dict get $sockets($socket) fanout] {
        if {[info exists conns($conn)]} {
            Write $conn [zmtp::frame $data $more]
        }
    }
    dict set sockets($socket) fanoutMore $more
    if {!$more} {
        dict set sockets($socket) fanout {}
    }
}

# XSUB remembers subscriptions it forwarded, to filter and resend on reconnect.
proc ::zmq::XsubTrack {socket subscribe topic} {
    variable sockets
    set subs [dict get $sockets($socket) subscriptions]
    if {$subscribe} {
        lappend subs $topic
    } else {
        set idx [lsearch -exact $subs $topic]
        if {$idx >= 0} {
            set subs [lreplace $subs $idx $idx]
        }
    }
    dict set sockets($socket) subscriptions $subs
}
