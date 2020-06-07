package require jmsg
package require rl_json
namespace import rl_json::json

set pipe {}
set exec_counter 0

proc execute_request {jmsg} {
    variable exec_counter
    incr exec_counter
    set status ok
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
    

    
    
    if {[catch {slave eval $code} result]} {
	set response [jmsg::newiopub $kernel_id $ph error]
	dict with response {
	    set content [json template {
		{
		    "ename":"~S:errorCode",
		    "evalue":"~S:result",
		    "traceback":"~S:errorInfo"
		}
	    }]
	}
	set status error
	respond $response
    } else {
	set response [jmsg::newiopub $kernel_id $ph execute_result]
	dict with response {
	    set content [json template {
		{
		    "data":"~S:result",
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
	set content [json template {
		{
		    "status":"~S:status",
		    "execution_count":"~N:exec_counter",
		    "user_expressions": {}

		}
	    }]
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
	puts "Handling $msg_type"
	handle $msg_type $jmsg
    } else {
	puts "Not handling $msg_type"
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


