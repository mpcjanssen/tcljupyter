package require Thread
package require rl_json
namespace import rl_json::json


proc connect {connection_file} {
    variable conn
    variable ports
    set f [open $connection_file]
    set conn [read $f]
    set key [json get $conn key]
    interp alias {} hmac {}  sha2::hmac -hex -key $key

    set iopub [listen iopub [address iopub] $key]
    listen shell [address shell] $key $iopub
    # listen control [address control]
    # listen stdin [address stdin]
    listen hb [address hb]
    vwait forever
}


proc listen {type args} {
    set t [thread::create thread::wait]
    thread::send $t [list tcl::tm::path add {*}[tcl::tm::path list]]
    thread::send $t [list set auto_path $::auto_path]
    thread::send $t [list package require jupyter_$type]
    thread::send -async $t [list start {*}$args]
    puts "[pid]: Started $type ($t) with $args"
    return $t

}

proc address {port} {
    variable conn
    set address [json get $conn transport]://
    append address [json get $conn ip]:
    append address [json get $conn ${port}_port]
    return $address
}



