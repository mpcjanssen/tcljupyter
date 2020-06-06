package require rl_json
package require sha256
namespace import ::rl_json::*
namespace eval jmsg {


    proc new {zmsg} {
	set buffers [lassign $zmsg port uuid delimiter hmac header parent metadata content]
	dict set result port $port
	dict set result uuid $uuid
	dict set result delimiter $delimiter
	dict set result hmac $hmac
	dict set result header $header
	dict set result parent $parent
	dict set result metadata $metadata
	dict set result content $content
	return $result
    }
    proc session {msg} {
	json get [dict get $msg header] session		
    }
}
