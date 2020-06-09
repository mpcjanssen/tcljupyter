package require rl_json 0.11.0-
package require sha256
package require uuid
namespace import ::rl_json::*
namespace eval jmsg {

  proc newheader {kernelid username msg_type} {
    set msg_id [newid]
    set date [clock format [clock seconds] -gmt 1 -format "%Y-%m-%dT%H:%M:%SZ"]
    json template {
      {"msg_id":"~S:msg_id",
        "msg_type":"~S:msg_type",
        "username":"~S:username",
        "session":"~S:kernelid",
        "date":"~S:date",
        "version":"5.3"
      }
    }  
  }

  proc newid {} {
    return [string map {- {}} [uuid::uuid generate]]   
  }

  proc new {zmsg} {
    set buffers [lassign $zmsg port kernel_id uuid delimiter hmac header parent metadata content]
    dict set result kernel_id $kernel_id
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
  proc parent_session {msg} {
    json get [dict get $msg parent] session		
  }

  proc type {msg} {
    json get [dict get $msg header] msg_type		
  }

  proc newiopub {kernel_id parent msg_type} {
    set username [json get $parent username]
    set header [jmsg::newheader $kernel_id $username $msg_type]
    set content [json template {{}}]
    set jmsg [list port iopub uuid $msg_type delimiter "<IDS|MSG>" parent $parent header $header hmac {} metadata {{}} content $content]
    return $jmsg 
  }

  proc status {kernel_id parent state} {
    set jmsg [newiopub $kernel_id $parent status]
    dict with jmsg {
      set content [json template {{"execution_state" : "~S:state"}}]   
    }
    return $jmsg    
  }

}
