package require jmsg
package require rl_json 0.11.0-
namespace import rl_json::json

set pipe {}
set ph {}
set kernel_id {}
set exec_counter 0

proc writechan {name cmd args} {
    switch -exact $cmd {
	initialize { return {initialize finalize write}}
	write {
	    lassign $args handle buffer
	    set text [encoding convertfrom [fconfigure stdout -encoding] $buffer]
	    stream $name $text
	    return $buffer
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

proc display {mimetype body} {
    variable ph
    variable kernel_id
    set response [jmsg::newiopub $kernel_id $ph display_data]
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
    variable ph
    variable kernel_id
    variable exec_counter
    incr exec_counter
    set status ok
    set ph [dict get $jmsg header]
    set kernel_id [dict get $jmsg kernel_id]

    interp alias slave ::jupyter::display {} display
    interp alias slave ::jupyter::html {} display text/html
    
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
	puts stderr [join [lrange [split $::errorInfo \n] 0 end-2] \n]
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
    # redirect stdout and stderr
    chan push stdout {writechan stdout} 
    chan push stderr {writechan stderr} 
    interp create slave
    vwait forever
}


