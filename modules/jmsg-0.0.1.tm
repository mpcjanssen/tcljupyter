package require rl_json 0.11.0-
package require sha256
package require uuid
namespace import ::rl_json::*
package require sha256
namespace eval jmsg {
    proc newheader {username msg_type} {
        set msg_id [newid]
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

    proc newid {} {
        return [string map {- {}} [uuid::uuid generate]]   
    }

    proc new {key zmsg} {
        set buffers [lassign $zmsg uuid delimiter hmac header parent metadata content]
        dict set result key $key
        dict set result uuid $uuid
        dict set result delimiter $delimiter
        dict set result hmac $hmac
        dict set result header $header
        dict set result parent $parent 
        dict set result metadata $metadata
        dict set result content $content
        set calc_hmac [sha2::hmac -hex -key $key [encoding convertto utf-8 "$header$parent$metadata$content"]]
        if {$calc_hmac ne $hmac} {
            puts "ERROR: HMAC mismatch $calc_hmac : $hmac"
            exit -1
        }
        return $result
    }
    proc znew {key jmsg} {
        dict with jmsg {
            dict set result uuid $uuid
            dict set result delimiter $delimiter
            dict set result header $header
            dict set result parent $parent
            dict set result metadata [encoding convertto utf-8 $metadata]
            dict set result content [encoding convertto utf-8 $content]
        }
        dict with result {
             set hmac [sha2::hmac -hex -key $key "$header$parent$metadata$content"]
             return [list $uuid $delimiter $hmac $header $parent $metadata $content]
        }
    }

    proc session {msg} {
        json get [dict get $msg header] session         
    }
    proc parent_session {msg} {
        json get [dict get $msg parent] session         
    }
    proc header {msg} {
        dict get $msg header
    }

    proc msg_type {msg} {
        json get [dict get $msg header] msg_type                
    }

    proc newiopub {parent msg_type} {
        set username [json get $parent username]
        set header [jmsg::newheader $username $msg_type]
        set content [json template {{}}]
        set jmsg [list uuid $msg_type delimiter "<IDS|MSG>" parent $parent header $header hmac {} metadata {{}} content $content]
        return $jmsg 
    }

    proc status {parent state} {
        set jmsg [newiopub $parent status]
        dict with jmsg {
            set content [json template {{"execution_state" : "~S:state"}}]   
        }
        return $jmsg    
    }

    proc send {jmsg key zsocket} {
         set zmsg [znew $key $jmsg]
         foreach zframe [lrange $zmsg 0 end-1] {
                 $zsocket sendmore $zframe
         }
         $zsocket send [lindex $zmsg end]

    }
}
