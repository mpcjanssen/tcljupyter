package require jmsg
package require rl_json 0.11.0-
namespace import rl_json::json

set pipe {}
set ph {}
set kernel_id {}
set exec_counter 0
set display_id 0
set indent_level 0
set lastPos 0

proc writechan {name cmd args} {
    switch -exact $cmd {
        initialize { return {initialize finalize write}}
        write {
            lassign $args handle buffer
            stream $name [encoding convertfrom [fconfigure $name -encoding] $buffer]
            return ""
        }
    }
}


proc stream {name text} {
    variable ph
    set response [jmsg::newiopub $ph stream]
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

proc execute_result {n result {mimetype "text/plain"}} {
    json template {
	{
	    "execution_count" : "~N:n",
	    "data": {"~S:mimetype" : "~S:result"},
	    "metadata" : {}
	}
    }
}

proc display {mimetype body} {
    variable display_id
    incr display_id
    set id display-id-$display_id
    variable ph
    set response [jmsg::newiopub $ph display_data]
    dict with response {
        set content [display_data $mimetype $body $id]
    }
    respond $response
    return $id
}

proc updatedisplay {id mimetype body} {
    variable ph
    set response [jmsg::newiopub $ph update_display_data]
    dict with response {
        set content [display_data $mimetype $body $id]
    }
    respond $response
}

proc bgerror {jmsg errorInfo} {
    variable exec_counter
    set ph [dict get $jmsg header]
    puts stderr [join [lrange [split $::errorInfo \n] 0 2] \n]
    dict with jmsg {
        set parent $ph
        set username [json get $ph username]
        set header  [jmsg::newheader $username execute_reply]
        set content [json template {
            {
                "status":"ok",
                "execution_count":"~N:exec_counter",
                "user_expressions": {}

            }
        }]       
    }
    respond $jmsg
    respond [jmsg::status $ph idle]  
}

proc complete_request {jmsg} {
    variable ph
    set ph [dict get $jmsg header]
    respond [jmsg::status $ph busy]
     
    set cursor_pos [json get [dict get $jmsg content] cursor_pos]
    set code [json get [dict get $jmsg content] code]
    set cursor_start $cursor_pos
    set cursor_end $cursor_pos

    if {[catch {lassign [slave eval [list ::jupyter::complete $code $cursor_pos]] matches cursor_start} err]} {
        set matches [json array [list string $err]]

    } else {
        set matches [lmap x $matches {list string $x}]
        set matches [json array {*}$matches]
    }
    dict with jmsg {
        set parent $ph
        set username [json get $header username]
        set header  [jmsg::newheader $username complete_reply]
        set content [json template {
            {
                "status":"ok",
                "matches":"~J:matches",
                "cursor_start":"~N:cursor_start",
                "cursor_end":"~N:cursor_end"


            }
        }]       
    }
    respond $jmsg
    respond [jmsg::status $ph idle]
}

proc is_complete_request {jmsg} {
    variable ph
    variable indent_level
    variable lastPos
    
    set ph [dict get $jmsg header]
    respond [jmsg::status $ph busy]
     
    set code [json get [dict get $jmsg content] code]
    append code \n
    if {[info complete $code]} {
	set status "complete"
	set indent_level 0
	set lastPos 0
    } else {
	set status "incomplete"
	set chunk [string range $code $lastPos end]
	if {[regexp -lineanchor {\{$} $chunk]} {
	    # puts incr
	    incr indent_level
	} elseif {[regexp -lineanchor {^\s*\}} $chunk]} {
	    # puts decr
	    incr indent_level -1
	}
	set lastPos [string length $code]
    }
    # TODO: add indent hint for status "incomplete"
    set b [string repeat "  " $indent_level]
    # puts code=$code
    # puts b.$indent_level=$b
    dict with jmsg {   
        set parent $ph
        set username [json get $header username]
        set header  [jmsg::newheader $username is_complete_reply]
	if {$status eq "incomplete"} {
	    set content [json template {
		{
		    "status":"~S:status",
		    "indent":"~S:b"
		}
	    }]
	} else {
	    set content [json template {
		{"status":"~S:status"}
	    }]
	}
    }
    # puts jmsg=$jmsg
    respond $jmsg
    respond [jmsg::status $ph idle]
}

proc execute_request {jmsg} {
    variable ph
    variable exec_counter
    incr exec_counter
    set ph [dict get $jmsg header]

    respond [jmsg::status $ph busy]

    set code [json get [dict get $jmsg content] code]
    set response [jmsg::newiopub $ph execute_input]
    dict with response {
        set content [json template {
            {
                "code":"~S:code",
                "execution_count":"~N:exec_counter"
            }
        }]
    }
    respond $response
    set lines [split $code \n]
    set error {}
    set code {}
    set magics {timeit 0 timeit_count 1 noresult 0}
    set expect_magics 1
    foreach line $lines {
	set trimmed [string trim $line]
	if {$expect_magics && [string range $trimmed 0 1] eq {%%}} {
	   set magic_parts [split $trimmed]
	   lassign $magic_parts magic_cmd magic_arg1 magic_arg2
           set magic_cmd [string range $magic_cmd 2 end]
	   switch -exact $magic_cmd {
		timeit {
                    dict set magics timeit 1
                    if {$magic_arg1 ne {}} {
                        dict set magics timeit_count $magic_arg1
                    }
                }
                noresult {
		    dict set magics noresult 1
                }
		default {set error "Invalid magic %%$magic_cmd"}
	   }
	   continue 
	} else {
          set expect_magics 0
	  lappend code $line
	}
    }
    if {$error ne {}} {
	slave eval [list puts stderr $error]
    } 
    set code [join $code \n]    
    dict with magics {
        set time_result [time {
    	   set error [catch {slave eval $code} result]
        } $timeit_count]
    }
    if {[dict get $magics timeit]} {
	slave eval [list jupyter::html "<code style='color:green;'>$time_result</code>"]
    }
    if {$error} {
        set emsg [join [lrange [split $::errorInfo \n] 0 end-2] \n]
	json set rcontent ename [json string "Tcl error"]; # error code, if present
	json set rcontent evalue [json string $result]
	json set rcontent traceback [json array [list "string" $emsg]]
	
	set err [jmsg::newiopub $ph error]
	dict with err {
	    set content $rcontent
	}
	puts stderr $emsg
	
	json set rcontent status [json string "error"]
	
    } else {
        if {$result ne {} && ![dict get $magics noresult]} {
	    set response [jmsg::newiopub $ph execute_result]
	    dict with response {
		set content [execute_result $exec_counter $result]
	    }
	    respond $response
	}
	
	json set rcontent status [json string "ok"]
	json set rcontent user_expressions [json object]
	json set rcontent payload [json array]
    }

    json set rcontent execution_count [json number $exec_counter]

    dict with jmsg {
        set parent $ph
        set username [json get $header username]
        set header  [jmsg::newheader $username execute_reply]
        set content $rcontent       
    }

    respond $jmsg
    respond [jmsg::status $ph idle]
}


proc respond {jmsg} {
    variable ::master
    thread::send -async $master [list respond $jmsg]
}
