package require rl_json 0.11.0-
package require sha256
package require uuid
namespace import ::rl_json::*
namespace eval jmsg {
    variable id
    proc newheader {username msg_type} {
        set msg_id [uuid::uuid generate]
        set date [clock format [clock seconds] -gmt 1 -format "%Y-%m-%dT%H:%M:%SZ"]
        json template {
            {"msg_id":"~S:msg_id",
                "msg_type":"~S:msg_type",
                "username":"~S:username",
                "date":"~S:date",
                "version":"5.3"
            }
        }  
    }

    proc new {channel name type delimiter hmac header parent metadata content} {
        dict set result name $name
        dict set result type $type
        dict set result channel $channel
        dict set result delimiter $delimiter
        dict set result hmac $hmac
        dict set result header $header
        dict set result parent $parent 
        dict set result metadata $metadata
        dict set result content $content
        dict set result uuid ""
        # puts "JMSG: $result"
        set calc_hmac [hmac [encoding convertto utf-8 "$header$parent$metadata$content"]]
        if {$calc_hmac ne $hmac} {
            return -code error "HMAC mismatch $calc_hmac : $hmac"
        }
        return $result
    }
    proc znew {jmsg} {
        
        dict with jmsg {
            set hmac [hmac [encoding convertto utf-8 "$header$parent$metadata$content"]]
            set result $delimiter
            lappend result $hmac
            lappend result $header
            lappend result $parent
            lappend result $metadata
            lappend result [encoding convertto utf-8 $content]
            return $result
        }
    }

    proc session {msg} {
        json get [dict get $msg header] session         
    }
    proc parent_session {msg} {
        json get [dict get $msg parent] session         
    }

    proc msg_type {msg} {
        json get [dict get $msg header] msg_type                
    }

    proc name {msg} {
        dict get $msg name              
    }

    proc channel {msg} {
        dict get $msg channel              
    }

    proc newiopub {parent msg_type} {
        set username [json get $parent username]
        set header [jmsg::newheader $username $msg_type]
        set content [json template {{}}]
        set jmsg [list port iopub uuid "" delimiter "<IDS|MSG>" parent $parent header $header hmac {} metadata {{}} content $content]
        return $jmsg 
    }

    proc status {parent state} {
        set jmsg [newiopub $parent status]
        dict with jmsg {
            set content [json template {{"execution_state" : "~S:state"}}]   
        }
        return $jmsg    
    }
}
