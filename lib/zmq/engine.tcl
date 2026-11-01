# Connection engine: runs ZMTP over Tcl channels on the event loop.
# Transports (and tests) hand connected channels to zmq::Attach.
#
# Phase 1 routing is generic: outgoing messages are load-balanced over ready
# pipes and incoming messages are fair-queued (PAIR/DEALER/PUSH/PULL style).
# Socket-type specific behaviour hooks into SendFrame/RecvFrame (phase 3).

namespace eval ::zmq {
    variable conns
    array set conns {}
    variable nextConn 0

    # Blocking waits: token -> coroutine ("" for vwait), token -> woken flag,
    # socket -> tokens.
    variable waiters
    variable wake
    variable sockWaiters
    array set waiters {}
    array set wake {}
    array set sockWaiters {}
    variable nextToken 0
}

# localProps (e.g. Peer-Address) are merged into the peer's metadata.
proc ::zmq::Attach {socket rchan {wchan ""} {localProps {}}} {
    variable conns
    variable nextConn
    variable sockets
    Live $socket
    if {$wchan eq ""} {
        set wchan $rchan
    }
    foreach chan [lsort -unique [list $rchan $wchan]] {
        fconfigure $chan -blocking 0 -translation binary -buffering full
    }
    set conn zmqconn[incr nextConn]
    set conns($conn) [dict create socket $socket rchan $rchan wchan $wchan \
        state greeting inbuf "" partial {} props $localProps stalled 0 eof 0 \
        endpoint "" routingId "" subs {}]
    dict lappend sockets($socket) pipes $conn
    if {[Write $conn [zmtp::greeting NULL 0]]} {
        fileevent $rchan readable [list ::zmq::OnReadable $conn]
    }
    return $conn
}

proc ::zmq::Write {conn bytes} {
    variable conns
    set chan [dict get $conns($conn) wchan]
    if {[catch {puts -nonewline $chan $bytes; flush $chan}]} {
        Detach $conn
        return 0
    }
    return 1
}

proc ::zmq::Detach {conn} {
    variable conns
    variable sockets
    if {![info exists conns($conn)]} {
        return
    }
    set c $conns($conn)
    unset conns($conn)
    foreach chan [lsort -unique [list [dict get $c rchan] [dict get $c wchan]]] {
        catch {fileevent $chan readable {}}
        # Non-blocking close flushes pending output in the background.
        catch {::close $chan}
    }
    set socket [dict get $c socket]
    if {[info exists sockets($socket)]} {
        dict set sockets($socket) pipes \
            [lsearch -all -inline -not -exact [dict get $sockets($socket) pipes] $conn]
        if {[dict get $sockets($socket) outconn] eq $conn} {
            dict set sockets($socket) outconn dropped
        }
        set key [dict get $c endpoint]
        if {$key ne "" && [dict exists $sockets($socket) endpoints $key]} {
            dict set sockets($socket) endpoints $key conns [lsearch -all -inline -not -exact \
                [dict get $sockets($socket) endpoints $key conns] $conn]
        }
        PipeGone $socket $conn $c
        Notify $socket
    }
}

proc ::zmq::OnReadable {conn} {
    variable conns
    if {![info exists conns($conn)]} {
        return
    }
    set chan [dict get $conns($conn) rchan]
    if {[catch {read $chan} data]} {
        Detach $conn
        return
    }
    dict append conns($conn) inbuf $data
    Process $conn
    if {[info exists conns($conn)] && [eof $chan]} {
        if {[dict get $conns($conn) stalled]} {
            # Detach once the buffered messages have been delivered.
            dict set conns($conn) eof 1
        } else {
            Detach $conn
        }
    }
}

proc ::zmq::Process {conn} {
    variable conns
    if {![catch {ProcessInput $conn} msg opts]} {
        return
    }
    set code [dict get $opts -errorcode]
    if {[lindex $code 0] ne "ZMTP"} {
        return -options $opts $msg
    }
    if {[info exists conns($conn)] && [dict get $conns($conn) state] ne "greeting"} {
        Write $conn [zmtp::error_command [lindex $code 2]]
    }
    Detach $conn
}

proc ::zmq::ProcessInput {conn} {
    variable conns
    # Parse from an offset and trim the buffer once, not after every frame.
    set buf [dict get $conns($conn) inbuf]
    set pos 0
    try {
        ProcessBuffer $conn $buf pos
    } finally {
        if {[info exists conns($conn)]} {
            dict set conns($conn) inbuf [string range $buf $pos end]
        }
    }
}

proc ::zmq::ProcessBuffer {conn buf posVar} {
    variable conns
    variable sockets
    variable const
    upvar 1 $posVar pos
    while {[info exists conns($conn)]} {
        set c $conns($conn)
        set socket [dict get $c socket]
        switch -- [dict get $c state] {
            greeting {
                set avail [expr {[string length $buf] - $pos}]
                if {$avail > 0 && [string index $buf $pos] ne "\xFF"} {
                    zmtp::ProtoError "bad signature"
                }
                if {$avail < 64} {
                    return
                }
                set greeting [zmtp::parse_greeting [string range $buf $pos [expr {$pos + 63}]]]
                if {[dict get $greeting mechanism] ne "NULL"} {
                    zmtp::ProtoError "unsupported mechanism [dict get $greeting mechanism]"
                }
                incr pos 64
                dict set conns($conn) state handshake
                set props {}
                set id [dict get $sockets($socket) options $const(ZMQ_ROUTING_ID)]
                if {$id ne ""} {
                    dict set props Identity $id
                }
                Write $conn [zmtp::ready \
                    [zmtp::type_name [dict get $sockets($socket) type]] $props]
            }
            handshake {
                set frame [zmtp::parse_frame $buf $pos]
                if {$frame eq ""} {
                    return
                }
                incr pos [dict get $frame length]
                if {![dict get $frame command]} {
                    zmtp::ProtoError "expected READY"
                }
                set cmd [zmtp::parse_command [dict get $frame body]]
                switch -- [dict get $cmd name] {
                    READY {}
                    ERROR {
                        Detach $conn
                        return
                    }
                    default {
                        zmtp::ProtoError "expected READY"
                    }
                }
                set props [PeerProps [zmtp::parse_metadata [dict get $cmd data]]]
                set ours [zmtp::type_name [dict get $sockets($socket) type]]
                if {![dict exists $props Socket-Type]
                        || ![zmtp::compatible $ours [dict get $props Socket-Type]]} {
                    zmtp::ProtoError "incompatible socket type"
                }
                dict set conns($conn) props [dict merge $props [dict get $c props]]
                dict set conns($conn) state ready
                PipeReady $conn
                Notify $socket
            }
            ready {
                if {[dict get $c stalled]} {
                    return
                }
                set frame [zmtp::parse_frame $buf $pos]
                if {$frame eq ""} {
                    return
                }
                incr pos [dict get $frame length]
                if {[dict get $frame command]} {
                    HandleCommand $conn [zmtp::parse_command [dict get $frame body]]
                    continue
                }
                dict lappend conns($conn) partial [dict get $frame body]
                if {![dict get $frame more]} {
                    Deliver $conn
                }
            }
        }
    }
}

# Canonicalise well-known property names (they are case-insensitive).
proc ::zmq::PeerProps {metadata} {
    set props {}
    dict for {name value} $metadata {
        foreach known {Socket-Type Identity Resource User-Id} {
            if {[string equal -nocase $name $known]} {
                set name $known
            }
        }
        dict set props $name $value
    }
    if {[dict exists $props Identity]} {
        dict set props Routing-Id [dict get $props Identity]
    }
    return $props
}

proc ::zmq::HandleCommand {conn cmd} {
    switch -- [dict get $cmd name] {
        PING {
            Write $conn [zmtp::command PONG [string range [dict get $cmd data] 2 end]]
        }
        ERROR {
            Detach $conn
        }
        SUBSCRIBE - CANCEL {
            PeerSubscription $conn [expr {[dict get $cmd name] eq "SUBSCRIBE"}] [dict get $cmd data]
        }
    }
}

proc ::zmq::Deliver {conn} {
    variable conns
    variable sockets
    variable const
    set c $conns($conn)
    set socket [dict get $c socket]
    set frames [dict get $c partial]
    dict set conns($conn) partial {}
    if {![RouteIncoming $conn frames]} {
        return
    }
    set origin {}
    if {[TypeName $socket] eq "REP"} {
        set origin [RepRequest $conn frames]
        if {$origin eq ""} {
            return
        }
    }
    Enqueue $socket $frames [dict get $conns($conn) props] $origin
    set hwm [dict get $sockets($socket) options $const(ZMQ_RCVHWM)]
    if {[info exists conns($conn)] && $hwm > 0
            && [llength [dict get $sockets($socket) inq]] >= $hwm} {
        dict set conns($conn) stalled 1
        fileevent [dict get $c rchan] readable {}
    }
}

proc ::zmq::Enqueue {socket frames props {origin {}}} {
    variable sockets
    dict lappend sockets($socket) inq [list $frames $props $origin]
    Notify $socket
}

proc ::zmq::Unstall {socket} {
    variable conns
    variable sockets
    variable const
    set hwm [dict get $sockets($socket) options $const(ZMQ_RCVHWM)]
    if {$hwm > 0 && [llength [dict get $sockets($socket) inq]] >= $hwm} {
        return
    }
    foreach conn [dict get $sockets($socket) pipes] {
        if {[dict get $conns($conn) stalled]} {
            dict set conns($conn) stalled 0
            if {![dict get $conns($conn) eof]} {
                fileevent [dict get $conns($conn) rchan] readable \
                    [list ::zmq::OnReadable $conn]
            }
            after 0 [list ::zmq::ResumeInput $conn]
        }
    }
}

proc ::zmq::ResumeInput {conn} {
    variable conns
    if {![info exists conns($conn)]} {
        return
    }
    Process $conn
    if {[info exists conns($conn)] && [dict get $conns($conn) eof]
            && ![dict get $conns($conn) stalled]} {
        Detach $conn
    }
}

# Round-robin over pipes that completed the handshake.
proc ::zmq::NextPipe {socket} {
    variable sockets
    variable conns
    set ready {}
    foreach conn [dict get $sockets($socket) pipes] {
        if {[dict get $conns($conn) state] eq "ready"} {
            lappend ready $conn
        }
    }
    if {![llength $ready]} {
        return ""
    }
    set rr [dict get $sockets($socket) rr]
    dict set sockets($socket) rr [expr {$rr + 1}]
    return [lindex $ready [expr {$rr % [llength $ready]}]]
}

# Current ZMQ_POLLIN/ZMQ_POLLOUT state of a socket.
proc ::zmq::Events {socket} {
    variable sockets
    variable conns
    variable const
    set state $sockets($socket)
    set events 0
    if {[CanRecv $socket]
            && ([llength [dict get $state curmsg]] || [llength [dict get $state inq]])} {
        set events [expr {$events | $const(ZMQ_POLLIN)}]
    }
    if {[CanSend $socket]} {
        if {[TypeName $socket] eq "REP"} {
            # Only a pending request can be answered.
            set writable [expr {[dict get $state reply] ne "" || [dict get $state outconn] ne ""}]
        } else {
            # These types never block on send: they route or drop.
            set writable [expr {[TypeName $socket] in {ROUTER PUB XPUB XSUB}
                || [dict get $state outconn] ne ""}]
            foreach conn [dict get $state pipes] {
                if {$writable} {
                    break
                }
                set writable [expr {[dict get $conns($conn) state] eq "ready"}]
            }
        }
        if {$writable} {
            set events [expr {$events | $const(ZMQ_POLLOUT)}]
        }
    }
    return $events
}

# Absolute deadline in ms, or -1 to wait forever.
proc ::zmq::Deadline {socket option flags} {
    variable sockets
    variable const
    set timeout [dict get $sockets($socket) options $const($option)]
    if {$flags & $const(ZMQ_DONTWAIT)} {
        set timeout 0
    }
    expr {$timeout < 0 ? -1 : [clock milliseconds] + $timeout}
}

proc ::zmq::SendFrame {socket data flags} {
    variable sockets
    variable const
    set more [expr {($flags & $const(ZMQ_SNDMORE)) != 0}]
    switch -- [TypeName $socket] {
        ROUTER {
            return [RouterSend $socket $data $more]
        }
        PUB - XPUB - XSUB {
            return [FanoutSend $socket $data $more]
        }
        REP {
            return [RepSend $socket $data $more]
        }
    }
    set conn [dict get $sockets($socket) outconn]
    if {$conn eq ""} {
        set deadline [Deadline $socket ZMQ_SNDTIMEO $flags]
        while {[set conn [NextPipe $socket]] eq ""} {
            if {$deadline >= 0 && [clock milliseconds] >= $deadline} {
                Fail EAGAIN
            }
            Wait $socket $deadline
            Live $socket
        }
    }
    # A pipe that died mid-message swallows the remaining frames.
    if {$conn ne "dropped" && ![Write $conn [zmtp::frame $data $more]]} {
        set conn dropped
    }
    dict set sockets($socket) outconn [expr {$more ? $conn : ""}]
}

proc ::zmq::RecvFrame {socket flags} {
    variable sockets
    variable const
    if {![llength [dict get $sockets($socket) curmsg]]} {
        if {[TypeName $socket] eq "REP" && [dict get $sockets($socket) reply] ne ""} {
            Fail EFSM
        }
        set deadline [Deadline $socket ZMQ_RCVTIMEO $flags]
        while {![llength [dict get $sockets($socket) inq]]} {
            if {$deadline >= 0 && [clock milliseconds] >= $deadline} {
                Fail EAGAIN
            }
            Wait $socket $deadline
            Live $socket
        }
        set inq [dict get $sockets($socket) inq]
        lassign [lindex $inq 0] frames props origin
        dict set sockets($socket) inq [lrange $inq 1 end]
        dict set sockets($socket) curmsg $frames
        dict set sockets($socket) curprops $props
        dict set sockets($socket) reply $origin
        Unstall $socket
    }
    set rest [lassign [dict get $sockets($socket) curmsg] data]
    set more [expr {[llength $rest] > 0}]
    dict set sockets($socket) curmsg $rest
    dict set sockets($socket) options $const(ZMQ_RCVMORE) $more
    dict create data $data more $more props [dict get $sockets($socket) curprops]
}

# Block until Notify on any of keys (socket handles) or the deadline. Inside a
# coroutine this yields to the event loop instead of entering a nested vwait.
proc ::zmq::Wait {keys deadline} {
    variable waiters
    variable wake
    variable sockWaiters
    variable nextToken
    set token [incr nextToken]
    set waiters($token) [info coroutine]
    foreach key $keys {
        lappend sockWaiters($key) $token
    }
    set timer ""
    if {$deadline >= 0} {
        set timer [after [expr {max(0, $deadline - [clock milliseconds])}] \
            [list ::zmq::Wake $token]]
    }
    if {$waiters($token) ne ""} {
        yield
    } else {
        vwait ::zmq::wake($token)
    }
    after cancel $timer
    unset waiters($token)
    unset -nocomplain wake($token)
    foreach key $keys {
        if {![info exists sockWaiters($key)]} {
            continue
        }
        set tokens [lsearch -all -inline -not -exact $sockWaiters($key) $token]
        if {[llength $tokens]} {
            set sockWaiters($key) $tokens
        } else {
            unset sockWaiters($key)
        }
    }
}

proc ::zmq::Wake {token} {
    variable waiters
    variable wake
    if {![info exists waiters($token)] || [info exists wake($token)]} {
        return
    }
    set wake($token) 1
    if {$waiters($token) ne ""} {
        after 0 [list $waiters($token)]
    }
}

proc ::zmq::Notify {socket} {
    variable sockWaiters
    if {[info exists sockWaiters($socket)]} {
        foreach token $sockWaiters($socket) {
            Wake $token
        }
    }
    ScheduleReadable $socket
}

# Run the zmq::readable handler from the event loop if input is pending.
proc ::zmq::ScheduleReadable {socket} {
    variable sockets
    if {![info exists sockets($socket)]
            || [dict get $sockets($socket) readable] eq ""
            || [dict get $sockets($socket) readableTimer] ne ""} {
        return
    }
    dict set sockets($socket) readableTimer [after 0 [list ::zmq::FireReadable $socket]]
}

proc ::zmq::FireReadable {socket} {
    variable sockets
    variable ctxs
    variable const
    if {![info exists sockets($socket)]} {
        return
    }
    dict set sockets($socket) readableTimer ""
    set script [dict get $sockets($socket) readable]
    if {$script eq ""
            || [dict get $ctxs([dict get $sockets($socket) ctx]) state] ne "active"
            || !([Events $socket] & $const(ZMQ_POLLIN))} {
        return
    }
    # Like fileevent: an error removes the handler and is reported via bgerror.
    if {[catch {uplevel #0 $script} msg opts]} {
        if {[info exists sockets($socket)]} {
            dict set sockets($socket) readable ""
        }
        return -options $opts $msg
    }
    # Level-triggered: fire again while input remains.
    ScheduleReadable $socket
}
