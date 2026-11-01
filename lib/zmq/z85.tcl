# Z85 encoding (ZeroMQ RFC 32): zmq_z85_encode / zmq_z85_decode.

namespace eval ::zmq {
    variable z85chars {0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ.-:+=^!/*?&<>()[]{}@%$#}
    variable z85values
    set i 0
    foreach ch [split $z85chars ""] {
        set z85values($ch) $i
        incr i
    }
    unset i ch
}

proc ::zmq::z85_encode {data} {
    variable z85chars
    if {[string length $data] % 4} {
        Fail EINVAL
    }
    set out ""
    binary scan $data Iu* words
    foreach value $words {
        set chunk ""
        for {set i 0} {$i < 5} {incr i} {
            set chunk [string index $z85chars [expr {$value % 85}]]$chunk
            set value [expr {$value / 85}]
        }
        append out $chunk
    }
    return $out
}

proc ::zmq::z85_decode {string} {
    variable z85values
    if {[string length $string] % 5} {
        Fail EINVAL
    }
    set out ""
    foreach {a b c d e} [split $string ""] {
        set value 0
        foreach ch [list $a $b $c $d $e] {
            if {![info exists z85values($ch)]} {
                Fail EINVAL
            }
            set value [expr {$value * 85 + $z85values($ch)}]
        }
        if {$value > 0xFFFFFFFF} {
            Fail EINVAL
        }
        append out [binary format I $value]
    }
    return $out
}

proc ::zmq::curve_keypair {} {
    # TODO: requires a pure Tcl Curve25519 implementation.
    Fail ENOTSUP
}

proc ::zmq::curve_public {secret} {
    Fail ENOTSUP
}
