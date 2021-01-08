package require rl_json 0.11.0-
package require sha256
package require uuid
namespace import ::rl_json::*
namespace eval jmsg {
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

    proc new {frames} {
         set result {}
         set index [lsearch $frames "<IDS|MSG>"]
         if {$index != -1} {
	    set frames [lrange $frames $index end]
         } else {
           return -code error "Can't find Jupyter delimiter"
         }
         lassign $frames delimiter hmac header parent metadata content
         set calc_hmac [hmac "$header$parent$metadata$content"]
         if {$calc_hmac ne $hmac} {
           return -code error "HMAC mismatch $calc_hmac : $hmac"
         }

         dict set result delimiter $delimiter
         dict set result hmac $hmac
         dict set result header $header
         dict set result parent $parent
         dict set result metadata [encoding convertfrom utf-8 $metadata]
         dict set result content [encoding convertfrom utf-8 $content]
         puts "JMSG: [lindex $frames 0]"

         return $result
     }

     proc frames {jmsg} {
                  set result {}
          dict with jmsg {
                  dict set result delimiter $delimiter
                  dict set result header $header
                  dict set result parent $parent
                  dict set result metadata [encoding convertto utf-8 $metadata]
                  dict set result content [encoding convertto utf-8 $content]
          }
          dict with result {
               set hmac [hmac "$header$parent$metadata$content"]
          }
          return [list {} $delimiter $hmac $header $parent $metadata $content]
     }


    proc session {msg} {
        json get [dict get $msg header] session         
    }
    proc parentsession {msg} {
        json get [dict get $msg parent] session         
    }

    proc msgtype {msg} {
        json get [dict get $msg header] msg_type
    }
    proc newiopub {parent msgtype} {
        set username [json get $parent username]
        set header [jmsg::newheader $username $msgtype]
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
