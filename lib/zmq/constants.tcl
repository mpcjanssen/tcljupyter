# Constants with the same names and values as zmq.h (libzmq 4.3).

namespace eval ::zmq {
    variable const

    # Socket types
    array set const {
        ZMQ_PAIR 0 ZMQ_PUB 1 ZMQ_SUB 2 ZMQ_REQ 3 ZMQ_REP 4 ZMQ_DEALER 5
        ZMQ_ROUTER 6 ZMQ_PULL 7 ZMQ_PUSH 8 ZMQ_XPUB 9 ZMQ_XSUB 10 ZMQ_STREAM 11
    }

    # Send/recv flags
    array set const {ZMQ_DONTWAIT 1 ZMQ_SNDMORE 2}

    # Message properties
    array set const {ZMQ_MORE 1 ZMQ_SHARED 3}

    # Poll events
    array set const {ZMQ_POLLIN 1 ZMQ_POLLOUT 2 ZMQ_POLLERR 4 ZMQ_POLLPRI 8}

    # Context options
    array set const {
        ZMQ_IO_THREADS 1 ZMQ_MAX_SOCKETS 2 ZMQ_SOCKET_LIMIT 3
        ZMQ_MAX_MSGSZ 5 ZMQ_MSG_T_SIZE 6 ZMQ_BLOCKY 70
    }

    # Security mechanisms
    array set const {ZMQ_NULL 0 ZMQ_PLAIN 1 ZMQ_CURVE 2 ZMQ_GSSAPI 3}

    # Socket options
    array set const {
        ZMQ_AFFINITY 4 ZMQ_ROUTING_ID 5 ZMQ_IDENTITY 5 ZMQ_SUBSCRIBE 6
        ZMQ_UNSUBSCRIBE 7 ZMQ_RATE 8 ZMQ_RECOVERY_IVL 9 ZMQ_SNDBUF 11
        ZMQ_RCVBUF 12 ZMQ_RCVMORE 13 ZMQ_FD 14 ZMQ_EVENTS 15 ZMQ_TYPE 16
        ZMQ_LINGER 17 ZMQ_RECONNECT_IVL 18 ZMQ_BACKLOG 19
        ZMQ_RECONNECT_IVL_MAX 21 ZMQ_MAXMSGSIZE 22 ZMQ_SNDHWM 23
        ZMQ_RCVHWM 24 ZMQ_MULTICAST_HOPS 25 ZMQ_RCVTIMEO 27 ZMQ_SNDTIMEO 28
        ZMQ_LAST_ENDPOINT 32 ZMQ_ROUTER_MANDATORY 33 ZMQ_TCP_KEEPALIVE 34
        ZMQ_TCP_KEEPALIVE_CNT 35 ZMQ_TCP_KEEPALIVE_IDLE 36
        ZMQ_TCP_KEEPALIVE_INTVL 37 ZMQ_IMMEDIATE 39 ZMQ_XPUB_VERBOSE 40
        ZMQ_IPV6 42 ZMQ_MECHANISM 43 ZMQ_PLAIN_SERVER 44 ZMQ_PLAIN_USERNAME 45
        ZMQ_PLAIN_PASSWORD 46 ZMQ_CURVE_SERVER 47 ZMQ_CURVE_PUBLICKEY 48
        ZMQ_CURVE_SECRETKEY 49 ZMQ_CURVE_SERVERKEY 50 ZMQ_PROBE_ROUTER 51
        ZMQ_REQ_CORRELATE 52 ZMQ_REQ_RELAXED 53 ZMQ_CONFLATE 54
        ZMQ_ZAP_DOMAIN 55 ZMQ_ROUTER_HANDOVER 56 ZMQ_HANDSHAKE_IVL 66
        ZMQ_HEARTBEAT_IVL 75 ZMQ_HEARTBEAT_TTL 76 ZMQ_HEARTBEAT_TIMEOUT 77
        ZMQ_XPUB_VERBOSER 78 ZMQ_CONNECT_TIMEOUT 79
    }
}

proc ::zmq::const {name} {
    variable const
    set key [ConstName $name]
    if {![info exists const($key)]} {
        Fail EINVAL "unknown constant \"$name\""
    }
    return $const($key)
}

# Normalise ZMQ_IO_THREADS, IO_THREADS, -io_threads, io_threads to ZMQ_IO_THREADS.
proc ::zmq::ConstName {name} {
    set name [string toupper [string trimleft $name -]]
    if {![string match ZMQ_* $name]} {
        set name ZMQ_$name
    }
    return $name
}

# Resolve an integer or a list of constant names (OR-ed together).
proc ::zmq::ToInt {value} {
    variable const
    if {[string is entier -strict $value]} {
        return $value
    }
    set result 0
    foreach name $value {
        set key [ConstName $name]
        if {![info exists const($key)]} {
            Fail EINVAL "unknown constant \"$name\""
        }
        set result [expr {$result | $const($key)}]
    }
    return $result
}
