package require tmq
package require rl_json
package require sha256

namespace import rl_json::json



proc connect {connection_file} {
    set f [open $connection_file]
    set conn [read $f]
    close $f
    set key [json get $conn key]
    puts $conn
    interp alias {} hmac {} sha2::hmac -hex -key $key
    tmq::serve ROUTER [json get $conn shell_port] shell
    tmq::serve ROUTER [json get $conn control_port] control
    tmq::serve ROUTER [json get $conn stdin_port] stdin
    tmq::serve PUB [json get $conn iopub_port] iopub
    tmq::serve REP [json get $conn hb_port] hb
    vwait forever
}



