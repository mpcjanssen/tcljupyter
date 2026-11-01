# tcp:// transport.

namespace eval ::zmq {
    # listener token -> endpoint key, so accept callbacks can find their endpoint
    variable listenerKeys
    array set listenerKeys {}
    variable nextListener 0
}

proc ::zmq::TcpBind {socket endpoint ep} {
    variable sockets
    variable const
    variable listenerKeys
    variable nextListener
    set host [dict get $ep host]
    set port [dict get $ep port]
    if {$port eq "*"} {
        set port 0
    }
    if {$host eq "*"} {
        set host [expr {[dict get $sockets($socket) options $const(ZMQ_IPV6)] ? "::" : "0.0.0.0"}]
    }
    set token [incr nextListener]
    # TODO: accept interface names (e.g. eth0) like libzmq.
    if {[catch {::socket -server [list ::zmq::TcpAccept $socket $token] -myaddr $host $port} listener opts]} {
        set code [lindex [dict get $opts -errorcode] 1]
        switch -- $code {
            EADDRINUSE - EADDRNOTAVAIL {Fail $code}
            EACCES {Fail EADDRNOTAVAIL}
            default {Fail ENODEV}
        }
    }
    lassign [fconfigure $listener -sockname] addr - boundPort
    if {[string match *:* $addr]} {
        set addr \[$addr\]
    }
    set key tcp://$addr:$boundPort
    set listenerKeys($token) $key
    dict set sockets($socket) endpoints $key [dict create \
        kind bind orig $endpoint listener $listener token $token conns {}]
    dict set sockets($socket) options $const(ZMQ_LAST_ENDPOINT) $key
}

proc ::zmq::TcpAccept {socket token chan addr port} {
    variable sockets
    variable conns
    variable listenerKeys
    if {![info exists listenerKeys($token)]
            || [catch {Attach $socket $chan "" [dict create Peer-Address $addr]} conn]} {
        catch {::close $chan}
        return
    }
    set key $listenerKeys($token)
    if {[info exists conns($conn)]} {
        dict set conns($conn) endpoint $key
        dict set sockets($socket) endpoints $key conns \
            [linsert [dict get $sockets($socket) endpoints $key conns] end $conn]
    }
}
