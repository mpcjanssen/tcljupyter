package require jmsg
package require rl_json
namespace import rl_json::json

set pipe {}
set exec_counter 0

proc display {kernel_id parent mimetype body} {
    set response [jmsg::newiopub $kernel_id $parent display_data]
    dict with response {
	set content [json template {
	    {
		"data":{"~S:mimetype": "~S:body"},
		"metadata":{}
	    }
	}]
    }
    respond $response
}

proc execute_request {jmsg} {
    variable exec_counter
    incr exec_counter
    set status ok
    set ph [dict get $jmsg header]
    set kernel_id [dict get $jmsg kernel_id]

    interp alias slave display {} display $kernel_id $ph
    
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
    

    
    set error {}
    if {[catch {slave eval $code} result]} {
	set error [list ename $::errorCode traceback [lrange [split $::errorInfo \n] 0 end-2] evalue $result]
	set response [jmsg::newiopub $kernel_id $ph error]
	dict with response {
	    dict with error {
		set content [json template {
		    {
			"ename":"~S:ename",
			"evalue":"~S:evalue"
		    }
		}]
		json set content traceback [json array {*}[lmap x [dict get $error traceback] {list string $x}]]
	    }

	}
	set status error
	respond $response
    } else {
	set response [jmsg::newiopub $kernel_id $ph execute_result]
	dict with response {
	    set content [json template {
		{
		    "data":{"text/plain": "~S:result"},
		    "execution_count":"~N:exec_counter"
		    

		}
	    }]
	}
	respond $response
    }
    dict with jmsg {
	set parent $header
	set username [json get $header username]
	set header  [jmsg::newheader $kernel_id $username execute_reply]
	if {$status eq "ok"} {
	    set content [json template {
		{
		    "status":"~S:status",
		    "execution_count":"~N:exec_counter",
		    "user_expressions": {}
		    
		}
	    }]
	} else {
	    # puts $error
	    dict with error {
		set content [json template {
		    {
			"status":"~S:status",
			"ename":"~S:ename",
			"evalue": "~S:evalue",
			"execution_count":"~N:exec_counter"
		    }
		}]
		json set content traceback [json array {*}[lmap x [lrange [dict get $error traceback] 0 end-2] {list string $x}]]
     
	    }
	    
	}
    }
    respond $jmsg
}


proc respond {jmsg} {
    variable ::pipe
    set l [string length $jmsg]
    puts -nonewline $pipe $l:$jmsg
    flush $pipe
}

proc handle {msg_type jmsg} {
    set kernel_id [dict get $jmsg kernel_id]
    set parent [dict get $jmsg header]

    respond [jmsg::status $kernel_id $parent busy]
    $msg_type $jmsg
    respond [jmsg::status $kernel_id $parent idle]
}

proc recv {chan} {
    set jmsg [read $chan]
    set kernel_id [dict get $jmsg kernel_id]
    set parent [dict get $jmsg header]
    set msg_type [json get $parent msg_type]
    if {[info commands $msg_type] ne {}} {
	# puts "Handling $msg_type"
	handle $msg_type $jmsg
    } else {
	# puts "Not handling $msg_type"
    }
}

proc listen {from to} {
    set ::pipe $to
    fconfigure $from -blocking 0
    fconfigure $from -translation binary

    fileevent $from readable [list recv $from]
    interp create slave
    vwait forever
}


