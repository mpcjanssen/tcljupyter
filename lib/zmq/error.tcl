# Error reporting: zmq::errno / zmq::strerror.
# Errors are symbolic (EAGAIN, ETERM, ...) because numeric errno values
# are platform dependent.

namespace eval ::zmq {
    variable errno ""
    variable errmsg
    array set errmsg {
        EADDRINUSE      "Address already in use"
        EADDRNOTAVAIL   "Can't assign requested address"
        EAGAIN          "Resource temporarily unavailable"
        ECONNREFUSED    "Connection refused"
        EFAULT          "Bad address"
        EFSM            "Operation cannot be accomplished in current state"
        EHOSTUNREACH    "Host unreachable"
        EINTR           "Interrupted system call"
        EINVAL          "Invalid argument"
        EMFILE          "Too many open files"
        EMSGSIZE        "Message too long"
        EMTHREAD        "No thread available"
        ENODEV          "No such device"
        ENOCOMPATPROTO  "The protocol is not compatible with the socket type"
        ENOENT          "No such file or directory"
        ENOTSOCK        "Socket operation on non-socket"
        ENOTSUP         "Operation not supported"
        EPROTONOSUPPORT "Protocol not supported"
        ETERM           "Context was terminated"
    }
}

proc ::zmq::errno {} {
    variable errno
    return $errno
}

proc ::zmq::strerror {code} {
    variable errmsg
    if {[info exists errmsg($code)]} {
        return $errmsg($code)
    }
    return "Unknown error $code"
}

# Raise a ZMQ error from the calling command.
proc ::zmq::Fail {code {message ""}} {
    variable errno $code
    if {$message eq ""} {
        set message [strerror $code]
    }
    return -code error -level 2 -errorcode [list ZMQ $code] $message
}
