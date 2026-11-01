# Contexts: zmq_ctx_new, zmq_ctx_term, zmq_ctx_shutdown, zmq_ctx_get/set.

namespace eval ::zmq {
    variable ctxs
    array set ctxs {}
    variable nextCtx 0
    variable ctxReadOnly [list $const(ZMQ_SOCKET_LIMIT) $const(ZMQ_MSG_T_SIZE)]
}

proc ::zmq::Ctx {ctx} {
    variable ctxs
    if {![info exists ctxs($ctx)]} {
        Fail EFAULT "invalid or terminated context \"$ctx\""
    }
    return $ctxs($ctx)
}

proc ::zmq::ctx_new {} {
    variable ctxs
    variable nextCtx
    variable const
    set handle zmqctx[incr nextCtx]
    set ctxs($handle) [dict create state active sockets {} options [dict create \
        $const(ZMQ_IO_THREADS)  1 \
        $const(ZMQ_MAX_SOCKETS) 1023 \
        $const(ZMQ_SOCKET_LIMIT) 65535 \
        $const(ZMQ_MAX_MSGSZ)   2147483647 \
        $const(ZMQ_MSG_T_SIZE)  64 \
        $const(ZMQ_IPV6)        0 \
        $const(ZMQ_BLOCKY)      1]]
    return $handle
}

proc ::zmq::ctx_get {ctx option} {
    set options [dict get [Ctx $ctx] options]
    set option [ToInt $option]
    if {![dict exists $options $option]} {
        Fail EINVAL
    }
    return [dict get $options $option]
}

proc ::zmq::ctx_set {ctx option value} {
    variable ctxs
    variable ctxReadOnly
    variable const
    set options [dict get [Ctx $ctx] options]
    set option [ToInt $option]
    if {![dict exists $options $option] || $option in $ctxReadOnly} {
        Fail EINVAL
    }
    if {![string is entier -strict $value]} {
        Fail EINVAL
    }
    if {$option == $const(ZMQ_MAX_SOCKETS)
            && ($value < 1 || $value > [dict get $options $const(ZMQ_SOCKET_LIMIT)])} {
        Fail EINVAL
    }
    dict set ctxs($ctx) options $option $value
    return
}

proc ::zmq::ctx_shutdown {ctx} {
    variable ctxs
    Ctx $ctx
    dict set ctxs($ctx) state shutdown
    foreach socket [dict get $ctxs($ctx) sockets] {
        Notify $socket
    }
    return
}

proc ::zmq::ctx_term {ctx} {
    variable ctxs
    set state [Ctx $ctx]
    # TODO: honour ZMQ_LINGER (flush pending outbound messages) before closing.
    foreach socket [dict get $state sockets] {
        close $socket
    }
    unset ctxs($ctx)
    return
}

# Deprecated alias kept for API completeness.
proc ::zmq::ctx_destroy {ctx} {
    ctx_term $ctx
}
