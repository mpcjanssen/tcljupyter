package provide jmsg 0.0.1
package require sha256
package require uuid
package require sqljson

namespace eval jmsg {
    proc newheader {username msg_type} {
        set msg_id [newid]
        set date [clock format [clock seconds] -gmt 1 -format "%Y-%m-%dT%H:%M:%SZ"]
        return [sqljson object \
            msg_id [sqljson str $msg_id] \
            msg_type [sqljson str $msg_type] \
            username [sqljson str $username] \
            date [sqljson str $date] \
            version [sqljson str 5.4]]
    }

proc newid {} {
    return [string map {- {}} [uuid::uuid generate]]   
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
    set calc_hmac [hmac [encoding convertto utf-8 "$header$parent$metadata$content"]]
    if {$calc_hmac ne $hmac} {
	puts "ERROR: HMAC mismatch $calc_hmac : $hmac"
	exit -1
    }
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
    sqljson get [dict get $msg header] session
}
proc parent_session {msg} {
    sqljson get [dict get $msg parent] session
}

proc type {msg} {
    sqljson get [dict get $msg header] msg_type
}

proc newiopub {parent msg_type} {
    set username [sqljson get $parent username]
    set header [jmsg::newheader $username $msg_type]
    set content {{}}
    set jmsg [list port iopub uuid $msg_type delimiter "<IDS|MSG>" parent $parent header $header hmac {} metadata {{}} content $content]
    return $jmsg 
}

# Return a header with its session field set
proc setsession {header session} {
    set fields [sqljson decode $header]
    dict set fields session $session
    return [sqljson object {*}[concat {*}[lmap {k v} $fields {list $k [sqljson str $v]}]]]
}

# Build a reply to jmsg with a fresh header of the given type
proc reply {jmsg msg_type content} {
    set parent [dict get $jmsg header]
    dict set jmsg parent $parent
    dict set jmsg header [newheader [sqljson get $parent username] $msg_type]
    dict set jmsg content $content
    return $jmsg
}

proc status {parent state} {
    set jmsg [newiopub $parent status]
    dict set jmsg content [sqljson object execution_state [sqljson str $state]]
    return $jmsg    
    }
}
