package require jmsg
package require rl_json 0.11.0-
namespace import rl_json::json

set pipe {}
set ph {}
set kernel_id {}
set exec_counter 0
set display_id 0

proc writechan {name cmd args} {
  switch -exact $cmd {
    initialize { return {initialize finalize write}}
    write {
      lassign $args handle buffer
      set text [encoding convertfrom [fconfigure stdout -encoding] $buffer]
      stream $name $text
      return ""
    }
  }
}


proc stream {name text} {
  variable ph
  variable kernel_id    
  set response [jmsg::newiopub $kernel_id $ph stream]
  dict with response {
    set content [json template {
      {
        "name":"~S:name",
        "text":"~S:text"
      }
    }]
  }
  respond $response
}

proc display_data {mimetype body id} {
  if {$mimetype ne "application/json"} {
    set content [json template {
      { 
        "data":{"~S:mimetype": "~S:body"},
        "metadata":{},
        "transient":{
          "display_id":"~S:id"
        }
      }
    }]
  } else {
    set content [json template {
      {
        "data":{
          "~S:mimetype": "~J:body",
          "text/plain": "~S:body"
        },
        "metadata":{},
        "transient":{
          "display_id":"~S:id"
        }
      }
    }]
  }
}

proc display {mimetype body} {
  variable display_id
  incr display_id
  set id display-id-$display_id
  variable ph
  variable kernel_id
  set response [jmsg::newiopub $kernel_id $ph display_data]
  dict with response {
    set content [display_data $mimetype $body $id]
  }
  respond $response
  return $id
}

proc updatedisplay {id mimetype body} {
  variable ph
  variable kernel_id
  set response [jmsg::newiopub $kernel_id $ph update_display_data]
  dict with response {
    set content [display_data $mimetype $body $id]
  }
  respond $response
}

proc bgerror {jmsg kernel_id tid errorInfo} {
  variable exec_counter
  set ph [dict get $jmsg header]
  puts stderr [join [lrange [split $::errorInfo \n] 0 2] \n]
   dict with jmsg {
    set parent $ph
    set username [json get $ph username]
    set header  [jmsg::newheader $kernel_id $username execute_reply]
    set content [json template {
      {
        "status":"ok",
        "execution_count":"~N:exec_counter",
        "user_expressions": {}

      }
    }]	 
  }
  respond $jmsg
  respond [jmsg::status $kernel_id $ph idle]  
}

proc execute_request {jmsg} {
  variable ph
  variable kernel_id
  variable exec_counter
  incr exec_counter
  set ph [dict get $jmsg header]
  set kernel_id [dict get $jmsg kernel_id]

  set code [json get [dict get $jmsg content] code]
  set response [jmsg::newiopub $kernel_id $ph execute_input]
  dict with response {
    set content [json template {
      {
        "code":"~S:code",
        "execution_count":"~N:exec_counter"
      }
    }]
  }
  respond $response

  respond [jmsg::status $kernel_id $ph busy]
  interp alias {} errorproc {} bgerror $jmsg $kernel_id $ph
  thread::errorproc errorproc
  if {[catch {slave eval $code} result]} {
    puts stderr [join [lrange [split $::errorInfo \n] 0 end-2] \n]
  } else {
    if {$result ne {} && [string index $code end] ne ";"} {puts stdout $result}
  }
  dict with jmsg {
    set parent $ph
    set username [json get $header username]
    set header  [jmsg::newheader $kernel_id $username execute_reply]
    set content [json template {
      {
        "status":"ok",
        "execution_count":"~N:exec_counter",
        "user_expressions": {}

      }
    }]	 
  }
  respond $jmsg
  respond [jmsg::status $kernel_id $ph idle]
}


proc respond {jmsg} {
  variable ::master
  thread::send -async $master [list respond $jmsg]
}
