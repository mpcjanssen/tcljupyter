# ZMTP 3.1 wire codec (https://rfc.zeromq.org/spec/37/).
# Pure functions on byte strings; no I/O. Protocol violations raise an
# error with errorCode {ZMTP PROTOCOL <reason>}.

namespace eval ::zmq::zmtp {
    variable typeNames {PAIR PUB SUB REQ REP DEALER ROUTER PULL PUSH XPUB XSUB STREAM}
    variable compatible {
        PAIR   {PAIR}
        PUB    {SUB XSUB}
        SUB    {PUB XPUB}
        REQ    {REP ROUTER}
        REP    {REQ DEALER}
        DEALER {REP DEALER ROUTER}
        ROUTER {REQ DEALER ROUTER}
        PULL   {PUSH}
        PUSH   {PULL}
        XPUB   {SUB XSUB}
        XSUB   {PUB XPUB}
    }
}

proc ::zmq::zmtp::ProtoError {reason} {
    return -code error -level 2 -errorcode [list ZMTP PROTOCOL $reason] \
        "ZMTP protocol error: $reason"
}

proc ::zmq::zmtp::type_name {type} {
    variable typeNames
    set name [lindex $typeNames $type]
    if {$name eq ""} {
        ProtoError "unknown socket type $type"
    }
    return $name
}

proc ::zmq::zmtp::compatible {ours theirs} {
    variable compatible
    expr {[dict exists $compatible $ours] && $theirs in [dict get $compatible $ours]}
}

# 64-byte greeting.
proc ::zmq::zmtp::greeting {{mechanism NULL} {asServer 0} {minor 1}} {
    if {[string length $mechanism] > 20} {
        ProtoError "mechanism name too long"
    }
    binary format cx8ccca20cx31 0xFF 0x7F 3 $minor $mechanism [expr {$asServer ? 1 : 0}]
}

proc ::zmq::zmtp::parse_greeting {bytes} {
    if {[string length $bytes] < 64} {
        ProtoError "short greeting"
    }
    binary scan $bytes cux8cucucua20cu sig end major minor mechanism asServer
    if {$sig != 0xFF || $end != 0x7F} {
        ProtoError "bad signature"
    }
    # TODO: detect ZMTP 1.0/2.0 peers from the first 11 bytes and downgrade.
    if {$major < 3} {
        ProtoError "unsupported ZMTP version $major.$minor"
    }
    dict create major $major minor $minor \
        mechanism [string trimright $mechanism "\0"] as_server $asServer
}

proc ::zmq::zmtp::frame {body {more 0} {command 0}} {
    if {$more && $command} {
        ProtoError "command frames cannot have MORE set"
    }
    set size [string length $body]
    set flags [expr {($more ? 1 : 0) | ($command ? 4 : 0)}]
    if {$size > 255} {
        set out [binary format cW [expr {$flags | 2}] $size]
    } else {
        set out [binary format cc $flags $size]
    }
    append out $body
}

# Returns {} if buffer holds no complete frame at offset, else a dict with
# more, command, body and length (bytes consumed).
proc ::zmq::zmtp::parse_frame {buffer {offset 0}} {
    set avail [expr {[string length $buffer] - $offset}]
    if {$avail < 2} {
        return {}
    }
    binary scan $buffer @${offset}cu flags
    if {$flags & 0xF8} {
        ProtoError "reserved flag bits set"
    }
    if {$flags & 2} {
        if {$avail < 9} {
            return {}
        }
        binary scan $buffer @[expr {$offset + 1}]Wu size
        set header 9
    } else {
        binary scan $buffer @[expr {$offset + 1}]cu size
        set header 2
    }
    set more [expr {($flags & 1) != 0}]
    set command [expr {($flags & 4) != 0}]
    if {$more && $command} {
        ProtoError "command frames cannot have MORE set"
    }
    if {$avail < $header + $size} {
        return {}
    }
    set start [expr {$offset + $header}]
    dict create more $more command $command \
        body [string range $buffer $start [expr {$start + $size - 1}]] \
        length [expr {$header + $size}]
}

proc ::zmq::zmtp::command {name {data ""}} {
    set len [string length $name]
    if {$len < 1 || $len > 255} {
        ProtoError "invalid command name"
    }
    frame [binary format c $len]$name$data 0 1
}

proc ::zmq::zmtp::parse_command {body} {
    if {![binary scan $body cu len] || [string length $body] < 1 + $len} {
        ProtoError "malformed command"
    }
    dict create name [string range $body 1 $len] \
        data [string range $body [expr {$len + 1}] end]
}

proc ::zmq::zmtp::metadata {props} {
    set out ""
    dict for {name value} $props {
        set len [string length $name]
        if {$len < 1 || $len > 255} {
            ProtoError "invalid property name"
        }
        append out [binary format c $len] $name \
            [binary format I [string length $value]] $value
    }
    return $out
}

# TODO: property names are case-insensitive per spec.
proc ::zmq::zmtp::parse_metadata {bytes} {
    set props {}
    set pos 0
    set total [string length $bytes]
    while {$pos < $total} {
        binary scan $bytes @${pos}cu nlen
        set name [string range $bytes [expr {$pos + 1}] [expr {$pos + $nlen}]]
        incr pos [expr {1 + $nlen}]
        if {$nlen == 0 || ![binary scan $bytes @${pos}Iu vlen]} {
            ProtoError "malformed metadata"
        }
        incr pos 4
        if {$pos + $vlen > $total} {
            ProtoError "malformed metadata"
        }
        dict set props $name [string range $bytes $pos [expr {$pos + $vlen - 1}]]
        incr pos $vlen
    }
    return $props
}

proc ::zmq::zmtp::error_command {reason} {
    set reason [string range $reason 0 254]
    command ERROR [binary format c [string length $reason]]$reason
}

proc ::zmq::zmtp::ready {socketType {props {}}} {
    command READY [metadata [dict merge [dict create Socket-Type $socketType] $props]]
}
