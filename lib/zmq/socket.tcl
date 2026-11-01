# Sockets: zmq_socket, zmq_close, zmq_setsockopt/getsockopt,
# zmq_bind/connect/unbind/disconnect, zmq_send/recv, zmq_poll, zmq_proxy.

namespace eval ::zmq {
    variable sockets
    array set sockets {}
    variable nextSocket 0

    # option -> {type default access}
    variable sockoptSpec {}
    foreach {name type default access} {
        ZMQ_AFFINITY          int    0     rw
        ZMQ_ROUTING_ID        bytes  {}    rw
        ZMQ_SUBSCRIBE         bytes  {}    w
        ZMQ_UNSUBSCRIBE       bytes  {}    w
        ZMQ_SNDBUF            int    -1    rw
        ZMQ_RCVBUF            int    -1    rw
        ZMQ_RCVMORE           int    0     r
        ZMQ_EVENTS            int    0     r
        ZMQ_TYPE              int    {}    r
        ZMQ_LINGER            int    -1    rw
        ZMQ_RECONNECT_IVL     int    100   rw
        ZMQ_BACKLOG           int    100   rw
        ZMQ_RECONNECT_IVL_MAX int    0     rw
        ZMQ_MAXMSGSIZE        int    -1    rw
        ZMQ_SNDHWM            int    1000  rw
        ZMQ_RCVHWM            int    1000  rw
        ZMQ_RCVTIMEO          int    -1    rw
        ZMQ_SNDTIMEO          int    -1    rw
        ZMQ_LAST_ENDPOINT     string {}    r
        ZMQ_ROUTER_MANDATORY  int    0     w
        ZMQ_TCP_KEEPALIVE     int    -1    rw
        ZMQ_IMMEDIATE         int    0     rw
        ZMQ_XPUB_VERBOSE      int    0     w
        ZMQ_IPV6              int    0     rw
        ZMQ_MECHANISM         int    0     r
        ZMQ_PROBE_ROUTER      int    0     w
        ZMQ_REQ_CORRELATE     int    0     w
        ZMQ_REQ_RELAXED       int    0     w
        ZMQ_CONFLATE          int    0     w
        ZMQ_ROUTER_HANDOVER   int    0     w
        ZMQ_HANDSHAKE_IVL     int    30000 rw
        ZMQ_HEARTBEAT_IVL     int    0     rw
        ZMQ_HEARTBEAT_TTL     int    0     rw
        ZMQ_HEARTBEAT_TIMEOUT int    -1    rw
        ZMQ_CONNECT_TIMEOUT   int    0     rw
    } {
        dict set sockoptSpec $const($name) [list $type $default $access]
    }
    unset name type default access
}

proc ::zmq::Socket {socket} {
    variable sockets
    if {![info exists sockets($socket)]} {
        Fail ENOTSOCK "invalid or closed socket \"$socket\""
    }
    return $sockets($socket)
}

# Like Socket, but also fails with ETERM once the context is shut down.
proc ::zmq::Live {socket} {
    variable ctxs
    set state [Socket $socket]
    if {[dict get $ctxs([dict get $state ctx]) state] ne "active"} {
        Fail ETERM
    }
    return $state
}

proc ::zmq::socket {ctx type} {
    variable ctxs
    variable sockets
    variable nextSocket
    variable sockoptSpec
    variable const
    set state [Ctx $ctx]
    if {[dict get $state state] ne "active"} {
        Fail ETERM
    }
    set type [ToInt $type]
    if {$type < $const(ZMQ_PAIR) || $type > $const(ZMQ_STREAM)} {
        Fail EINVAL
    }
    if {[llength [dict get $state sockets]]
            >= [dict get $state options $const(ZMQ_MAX_SOCKETS)]} {
        Fail EMFILE
    }
    set options {}
    dict for {option spec} $sockoptSpec {
        dict set options $option [lindex $spec 1]
    }
    set handle zmqsock[incr nextSocket]
    set sockets($handle) [dict create \
        ctx $ctx type $type options $options subscriptions {} endpoints {} \
        pipes {} inq {} curmsg {} curprops {} outconn {} rr 0 \
        readable {} readableTimer {} \
        routes {} nextRid [expr {int(rand() * 0xFFFFFFFF)}] \
        fanout {} fanoutMore 0 subcount {}]
    dict lappend ctxs($ctx) sockets $handle
    return $handle
}

proc ::zmq::close {socket} {
    variable sockets
    variable ctxs
    set state [Socket $socket]
    set ctx [dict get $state ctx]
    # TODO (phase 2): stop reconnect timers.
    foreach key [dict keys [dict get $state endpoints]] {
        CloseEndpoint $socket $key
    }
    foreach conn [dict get $sockets($socket) pipes] {
        Detach $conn
    }
    if {[info exists ctxs($ctx)]} {
        set list [dict get $ctxs($ctx) sockets]
        set idx [lsearch -exact $list $socket]
        dict set ctxs($ctx) sockets [lreplace $list $idx $idx]
    after cancel [dict get $sockets($socket) readableTimer]
    }
    unset sockets($socket)
    Notify $socket
    return
}

proc ::zmq::getsockopt {socket option} {
    variable sockoptSpec
    variable const
    set state [Socket $socket]
    set option [ToInt $option]
    if {![dict exists $sockoptSpec $option]
            || "r" ni [split [lindex [dict get $sockoptSpec $option] 2] ""]} {
        Fail EINVAL
    }
    if {$option == $const(ZMQ_TYPE)} {
        return [dict get $state type]
    }
    if {$option == $const(ZMQ_EVENTS)} {
        return [Events $socket]
    }
    return [dict get $state options $option]
}

proc ::zmq::setsockopt {socket option value} {
    variable sockets
    variable sockoptSpec
    variable const
    set state [Socket $socket]
    set option [ToInt $option]
    if {![dict exists $sockoptSpec $option]} {
        Fail EINVAL
    }
    lassign [dict get $sockoptSpec $option] type default access
    if {"w" ni [split $access ""]} {
        Fail EINVAL
    }
    if {$type eq "int" && ![string is entier -strict $value]} {
        Fail EINVAL
    }
    if {$option == $const(ZMQ_SUBSCRIBE) || $option == $const(ZMQ_UNSUBSCRIBE)} {
        if {[dict get $state type] ni [list $const(ZMQ_SUB) $const(ZMQ_XSUB)]} {
            Fail EINVAL
        }
        set subs [dict get $state subscriptions]
        set subscribe [expr {$option == $const(ZMQ_SUBSCRIBE)}]
        if {$subscribe} {
            lappend subs $value
        } else {
            set idx [lsearch -exact $subs $value]
            if {$idx < 0} {
                return
            }
            set subs [lreplace $subs $idx $idx]
        }
        dict set sockets($socket) subscriptions $subs
        SendSubscription $socket $subscribe $value
        return
    }
    dict set sockets($socket) options $option $value
    return
}

# Parse "transport://address" into a dict.
proc ::zmq::ParseEndpoint {endpoint} {
    if {![regexp {^([a-z]+)://(.+)$} $endpoint -> transport address]} {
        Fail EINVAL
    }
    switch -- $transport {
        tcp {
            # TODO: support "source;host:port" connect syntax.
            if {![regexp {^(\[[^\]]+\]|[^:\[\]]+):(\*|[0-9]+)$} $address -> host port]} {
                Fail EINVAL
            }
            if {$port ne "*"} {
                scan $port %d port
                if {$port > 65535} {
                    Fail EINVAL
                }
            }
            return [dict create transport tcp host [string trim $host {[]}] port $port]
        }
        inproc - ipc {
            return [dict create transport $transport address $address]
        }
        default {
            Fail EPROTONOSUPPORT
        }
    }
}

proc ::zmq::bind {socket endpoint} {
    Live $socket
    set ep [ParseEndpoint $endpoint]
    switch -- [dict get $ep transport] {
        tcp {
            TcpBind $socket $endpoint $ep
        }
        default {
            # TODO: inproc registry.
            Fail ENOTSUP
        }
    }
    return
}

proc ::zmq::connect {socket endpoint} {
    Live $socket
    ParseEndpoint $endpoint
    # TODO: tcp connect with reconnect, inproc pipes.
    Fail ENOTSUP
}

# Find a bound/connected endpoint by its resolved name, or by the original
# string when that contained no wildcard (libzmq semantics).
proc ::zmq::FindEndpoint {socket endpoint kind} {
    variable sockets
    dict for {key ep} [dict get $sockets($socket) endpoints] {
        if {[dict get $ep kind] ne $kind} {
            continue
        }
        if {$key eq $endpoint
                || ([dict get $ep orig] eq $endpoint && ![string match {*\**} $endpoint])} {
            return $key
        }
    }
    return ""
}

# Stop the listener of an endpoint and drop the connections it created.
proc ::zmq::CloseEndpoint {socket key} {
    variable sockets
    variable listenerKeys
    set ep [dict get $sockets($socket) endpoints $key]
    if {[dict exists $ep listener]} {
        catch {::close [dict get $ep listener]}
        unset -nocomplain listenerKeys([dict get $ep token])
    }
    foreach conn [dict get $ep conns] {
        Detach $conn
    }
    dict unset sockets($socket) endpoints $key
}

proc ::zmq::unbind {socket endpoint} {
    Live $socket
    set key [FindEndpoint $socket $endpoint bind]
    if {$key eq ""} {
        Fail ENOENT
    }
    CloseEndpoint $socket $key
    return
}

proc ::zmq::disconnect {socket endpoint} {
    Live $socket
    if {[FindEndpoint $socket $endpoint connect] eq ""} {
        Fail ENOENT
    }
    Fail ENOTSUP
}

proc ::zmq::CanSend {socket} {
    variable sockets
    variable const
    expr {[dict get $sockets($socket) type] ni [list $const(ZMQ_SUB) $const(ZMQ_PULL)]}
}

proc ::zmq::CanRecv {socket} {
    variable sockets
    variable const
    expr {[dict get $sockets($socket) type] ni [list $const(ZMQ_PUB) $const(ZMQ_PUSH)]}
}

# zmq_send: returns the number of bytes queued.
proc ::zmq::send {socket data {flags 0}} {
    Live $socket
    set flags [ToInt $flags]
    if {$flags & ~3} {
        Fail EINVAL "invalid send flags $flags"
    }
    if {![CanSend $socket]} {
        Fail ENOTSUP
    }
    CheckBytes $data
    SendFrame $socket $data $flags
    return [string length $data]
}

# Frames are bytes; reject characters that cannot be sent as a single byte.
proc ::zmq::CheckBytes {data {what "data"}} {
    if {[regexp -indices {[^\x00-\xff]} $data range]} {
        set idx [lindex $range 0]
        set char [string index $data $idx]
        Fail EINVAL [format {%s contains non-byte character U+%04X at index %d (convert text with: encoding convertto utf-8)} \
            $what [scan $char %c] $idx]
    }
}

proc ::zmq::send_const {socket data {flags 0}} {
    send $socket $data $flags
}

# zmq_recv: returns the received frame (no truncation, unlike C).
proc ::zmq::recv {socket {flags 0}} {
    Live $socket
    set flags [ToInt $flags]
    if {![CanRecv $socket]} {
        Fail ENOTSUP
    }
    return [dict get [RecvFrame $socket $flags] data]
}

# Tcl extension: receive all (remaining) frames of a message as a list.
proc ::zmq::recv_multipart {socket {flags 0}} {
    Live $socket
    set flags [ToInt $flags]
    if {![CanRecv $socket]} {
        Fail ENOTSUP
    }
    set frame [RecvFrame $socket $flags]
    set frames [list [dict get $frame data]]
    # Messages are queued whole, so the remaining frames never block.
    while {[dict get $frame more]} {
        set frame [RecvFrame $socket 0]
        lappend frames [dict get $frame data]
    }
    return $frames
}

# Tcl extension: send a list of frames as one message. Returns the total bytes.
proc ::zmq::send_multipart {socket frames {flags 0}} {
    variable const
    Live $socket
    set flags [ToInt $flags]
    if {$flags & ~3} {
        Fail EINVAL "invalid send flags $flags"
    }
    if {![llength $frames]} {
        Fail EINVAL "no frames to send"
    }
    if {![CanSend $socket]} {
        Fail ENOTSUP
    }
    # Validate everything first so a bad frame cannot leave a partial message.
    set i 0
    foreach frame $frames {
        CheckBytes $frame "frame $i"
        incr i
    }
    set total 0
    foreach frame [lrange $frames 0 end-1] {
        SendFrame $socket $frame [expr {$flags | $const(ZMQ_SNDMORE)}]
        incr total [string length $frame]
    }
    SendFrame $socket [lindex $frames end] $flags
    expr {$total + [string length [lindex $frames end]]}
}

namespace eval ::zmq {
    variable nextPoll 0
    # poll id,channel -> events seen by fileevent handlers
    variable pollSeen
    array set pollSeen {}
}

# zmq_poll: items is a list of {socket-or-channel events}. Returns the list of
# revents in item order.
proc ::zmq::poll {items {timeout -1}} {
    variable pollSeen
    variable nextPoll
    variable const
    if {![string is entier -strict $timeout]} {
        Fail EINVAL
    }
    set parsed {}
    set socks {}
    set chans {}
    set chanMask {}
    foreach item $items {
        if {[llength $item] != 2} {
            Fail EINVAL "poll item must be {socket-or-channel events}: \"$item\""
        }
        lassign $item handle events
        set events [ToInt $events]
        if {[info exists ::zmq::sockets($handle)]} {
            Live $handle
            lappend socks $handle
            lappend parsed socket $handle $events
        } elseif {$handle in [chan names]} {
            lappend chans $handle
            set old [expr {[dict exists $chanMask $handle] ? [dict get $chanMask $handle] : 0}]
            dict set chanMask $handle [expr {$old | $events}]
            lappend parsed channel $handle $events
        } else {
            Fail ENOTSOCK "invalid or closed socket \"$handle\""
        }
    }
    set id zmqpoll[incr nextPoll]
    set saved {}
    try {
        dict for {chan mask} $chanMask {
            set pollSeen($id,$chan) 0
            foreach {event bit} [list readable $const(ZMQ_POLLIN) writable $const(ZMQ_POLLOUT)] {
                if {!($mask & $bit)} {
                    continue
                }
                if {[catch {fileevent $chan $event} old]} {
                    Fail EINVAL "channel \"$chan\" is not $event"
                }
                lappend saved $chan $event $old
                fileevent $chan $event [list ::zmq::PollChannel $id $chan $bit]
            }
        }
        set deadline [expr {$timeout < 0 ? -1 : [clock milliseconds] + $timeout}]
        # Channel readiness is only known after visiting the event loop once.
        set visited [expr {![llength $chans]}]
        while 1 {
            set revents {}
            set ready 0
            foreach {kind handle events} $parsed {
                if {$kind eq "socket"} {
                    Live $handle
                    set r [expr {[Events $handle] & $events}]
                } else {
                    set r [expr {$pollSeen($id,$handle) & $events}]
                }
                lappend revents $r
                incr ready [expr {$r != 0}]
            }
            set expired [expr {$deadline >= 0 && [clock milliseconds] >= $deadline}]
            if {$visited && ($ready || $expired)} {
                return $revents
            }
            Wait [list {*}$socks $id] [expr {$ready ? [clock milliseconds] : $deadline}]
            set visited 1
        }
    } finally {
        foreach {chan event script} $saved {
            catch {fileevent $chan $event $script}
        }
        array unset pollSeen $id,*
    }
}

proc ::zmq::PollChannel {id chan bit} {
    variable pollSeen
    set pollSeen($id,$chan) [expr {$pollSeen($id,$chan) | $bit}]
    # Stop the handler from firing repeatedly while the poll is not waiting.
    fileevent $chan [expr {$bit == 1 ? "readable" : "writable"}] {}
    Notify $id
}

# Tcl extension, modelled on fileevent: evaluate script at global level
# whenever the socket has a message to receive.
proc ::zmq::readable {socket args} {
    variable sockets
    set state [Socket $socket]
    switch -- [llength $args] {
        0 {
            return [dict get $state readable]
        }
        1 {
            if {![CanRecv $socket]} {
                Fail ENOTSUP
            }
            dict set sockets($socket) readable [lindex $args 0]
            ScheduleReadable $socket
            return
        }
        default {
            return -code error -errorcode {TCL WRONGARGS} \
                {wrong # args: should be "zmq::readable socket ?script?"}
        }
    }
}

proc ::zmq::proxy {frontend backend {capture ""}} {
    Fail ENOTSUP
}

proc ::zmq::proxy_steerable {frontend backend {capture ""} {control ""}} {
    Fail ENOTSUP
}

proc ::zmq::socket_monitor {socket endpoint events} {
    Fail ENOTSUP
}
