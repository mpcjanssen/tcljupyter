package require rl_json
package require sha256
namespace import ::rl_json::*
namespace eval jmsg {

    proc updatehmac {jmsg key} {
	puts "Calculating hmac with key:$key"
	dict with jmsg {
	    set hmac [sha2::hmac -hex -key $key  "$header$parent$metadata$content"]
	}
	return $jmsg
    }

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
    proc znew {jmsg} {
	dict with jmsg {
	    set result $uuid
	    lappend result $delimiter
	    lappend result $hmac
	    lappend result $header
	    lappend result $parent
	    lappend result $metadata
	    lappend result $content
	    return $result
	}
    }
    
    proc session {msg} {
	json get [dict get $msg header] session		
    }
    proc type {msg} {
	json get [dict get $msg header] msg_type		
    }
}
