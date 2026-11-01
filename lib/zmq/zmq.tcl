# Pure Tcl implementation of ZeroMQ (ZMTP 3.x) with a libzmq-style API.
#
# API convention: C function zmq_foo(...) maps to Tcl command zmq::foo.
# - Handles (contexts, sockets, messages) are opaque strings.
# - Option, type and flag arguments accept integers or constant names
#   (e.g. ZMQ_ROUTER, {ZMQ_SNDMORE ZMQ_DONTWAIT}).
# - C functions returning 0/-1 return an empty string or raise an error
#   with errorCode {ZMQ <ERRNO>} (and set zmq::errno).
# - Buffers are Tcl byte strings; pointer/length pairs collapse to one value.
#
# NOTE: zmq::socket and zmq::close shadow Tcl builtins inside this
# namespace. Internal code must use ::socket and ::close for channels.

package require Tcl 8.6-

namespace eval ::zmq {
    variable library [file dirname [file normalize [info script]]]
    namespace export {[a-z]*}
    namespace ensemble create
}

foreach file {constants error context socket msg engine routing tcp z85 zmtp} {
    source [file join $::zmq::library $file.tcl]
}
unset file

# Version of the libzmq API being emulated.
proc ::zmq::version {} {
    return {4 3 5}
}

proc ::zmq::has {capability} {
    # TODO: report "curve" once CURVE is implemented.
    return 0
}

package provide zmq 0.1.0
