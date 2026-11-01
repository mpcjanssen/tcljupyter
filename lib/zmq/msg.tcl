# Messages: zmq_msg_* functions. A message handle replaces zmq_msg_t.

namespace eval ::zmq {
    variable msgs
    array set msgs {}
    variable nextMsg 0
}

proc ::zmq::NewMsg {data} {
    variable msgs
    variable nextMsg
    set handle zmqmsg[incr nextMsg]
    set msgs($handle) [dict create data $data more 0 props {}]
    return $handle
}

proc ::zmq::Msg {msg} {
    variable msgs
    if {![info exists msgs($msg)]} {
        Fail EFAULT "invalid or closed message \"$msg\""
    }
    return $msgs($msg)
}

proc ::zmq::msg_init {} {
    NewMsg ""
}

proc ::zmq::msg_init_size {size} {
    if {![string is entier -strict $size] || $size < 0} {
        Fail EINVAL
    }
    NewMsg [binary format x$size]
}

proc ::zmq::msg_init_data {data} {
    NewMsg $data
}

proc ::zmq::msg_data {msg} {
    dict get [Msg $msg] data
}

proc ::zmq::msg_size {msg} {
    string length [dict get [Msg $msg] data]
}

proc ::zmq::msg_more {msg} {
    dict get [Msg $msg] more
}

proc ::zmq::msg_get {msg property} {
    variable const
    set state [Msg $msg]
    set property [ToInt $property]
    if {$property == $const(ZMQ_MORE)} {
        return [dict get $state more]
    }
    if {$property == $const(ZMQ_SHARED)} {
        return 0
    }
    Fail EINVAL
}

proc ::zmq::msg_set {msg property value} {
    Msg $msg
    Fail EINVAL
}

# Metadata from the peer (e.g. Socket-Type, Routing-Id, Peer-Address).
proc ::zmq::msg_gets {msg property} {
    set props [dict get [Msg $msg] props]
    if {![dict exists $props $property]} {
        Fail EINVAL
    }
    return [dict get $props $property]
}

proc ::zmq::msg_close {msg} {
    variable msgs
    Msg $msg
    unset msgs($msg)
    return
}

proc ::zmq::msg_copy {dest src} {
    variable msgs
    Msg $dest
    set msgs($dest) [Msg $src]
    return
}

proc ::zmq::msg_move {dest src} {
    variable msgs
    Msg $dest
    set msgs($dest) [Msg $src]
    set msgs($src) [dict create data "" more 0 props {}]
    return
}

proc ::zmq::msg_send {msg socket {flags 0}} {
    variable msgs
    set n [send $socket [dict get [Msg $msg] data] $flags]
    set msgs($msg) [dict create data "" more 0 props {}]
    return $n
}

proc ::zmq::msg_recv {msg socket {flags 0}} {
    variable msgs
    Msg $msg
    Live $socket
    set frame [RecvFrame $socket [ToInt $flags]]
    set msgs($msg) $frame
    return [string length [dict get $frame data]]
}
