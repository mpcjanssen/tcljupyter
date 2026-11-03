package provide sessionclient 0.0.1
package require jmsg
package require jlib

namespace eval sessionclient {
    # Header of the request being handled; used to parent iopub messages
    variable ph {}
    variable master {}
    variable exec_counter 0
    variable display_id 0
    variable indent_level 0
    variable lastPos 0

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
        dict set response content [json new name $name text $text]
        respond $response
    }

    proc display_data {mimetype body id} {
        if {$mimetype ne "application/json"} {
            set content [json new] 
            json nest content data [json new $mimetype $body]
            json nest content metadata [json new]
            json nest content transient [json new display_id $id]

        } else {
            set data [json new text/plain $body]
            json nest data $mimetype $body
            set content [json new]
            json nest content data $data
            json set content metadata [json new]
            json nest content transient [json new display_id $id]
        }
        return $content

    }

    proc execute_result {n result {mimetype "text/plain"}} {
        set data [json new $mimetype $result]

        set result [json new execution_count $n]
        json nest result data $data
        json nest result metadata [json new]
        return $result
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

    proc report_error {jmsg} {
        variable exec_counter
        set ph [dict get $jmsg header]
        puts stderr [join [lrange [split $::errorInfo \n] 0 2] \n]
        set content [json new status ok execution_count $exec_counter]
        json nest content user_expressions [json new]
        respond [jmsg::reply $jmsg execute_reply $content]
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

        if {[catch {lassign [child eval [list ::jupyter::complete $code $cursor_pos]] matches cursor_start} err]} {
            set matches [json array [list string $err]]

        } else {
            set matches [lmap x $matches {list string $x}]
            set matches [json array {*}$matches]
        }
        set content [json template new status ok matches $matches cursor_start $cursor_start cursor_end $cursor_end]
        respond [jmsg::reply $jmsg complete_reply $content]
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
        }  {
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
        if {$status eq "incomplete"} {
            set content [json new status $status indent [string repeat "  " $indent_level]]
        } else {
            set content [json new status $status]
        }
        respond [jmsg::reply $jmsg is_complete_reply $content]
        respond [jmsg::status $ph idle]
    }

    # Split leading "##magic" lines from the code.
    # Returns {code magics error}
    proc parse_magics {code} {
        set magics {timeit 0 timeit_count 1 noresult 0}
        set error {}
        set body {}
        set expect_magics 1
        foreach line [split $code \n] {
            set trimmed [string trim $line]
            if {$expect_magics && [string range $trimmed 0 1] eq {##}} {
                lassign [split $trimmed] magic_cmd magic_arg
                switch -exact [string range $magic_cmd 2 end] {
                    timeit {
                        dict set magics timeit 1
                        if {$magic_arg ne {}} {
                            dict set magics timeit_count $magic_arg
                        }
                    }
                    noresult {
                        dict set magics noresult 1
                    }
                    default {
                        set error "Invalid magic $magic_cmd"
                    }
                }
            } else {
                set expect_magics 0
                lappend body $line
            }
        }
        set body [join $body \n]
        if {[string index [string trim $body] end] eq ";"} {
            dict set magics noresult 1
        }
        return [list $body $magics $error]
    }

    # Evaluate code in the child interpreter.
    # Returns {failed result time_result}
    proc run_code {code timeit_count} {
        set time_result [time {
            set failed [catch {child eval $code} result]
        } $timeit_count]
        return [list $failed $result $time_result]
    }

    proc execute_request {jmsg} {
        variable ph
        variable exec_counter
        incr exec_counter
        set ph [dict get $jmsg header]

        respond [jmsg::status $ph busy]

        set code [json get [dict get $jmsg content] code]
        set response [jmsg::newiopub $ph execute_input]
        dict set response content [json new code $code execution_count $exec_counter]
        respond $response

        lassign [parse_magics $code] code magics error
        if {$error ne {}} {
            child eval [list puts stderr $error]
        }
        lassign [run_code $code [dict get $magics timeit_count]] failed result time_result
        if {[dict get $magics timeit]} {
            child eval [list jupyter::html "<code style='color:green;'>$time_result</code>"]
        }

        set rcontent [json new]
        if {$failed} {
            set emsg [join [lrange [split $::errorInfo \n] 0 end-2] \n]
            puts stderr $emsg
            json set rcontent ename "Tcl error"
            json set rcontent evalue $result
            json set rcontent traceback [json arr [list "string" $emsg]]
            json set rcontent status error
        } else {
            if {$result ne {} && ![dict get $magics noresult]} {
                set response [jmsg::newiopub $ph execute_result]
                dict set response content [execute_result $exec_counter $result]
                respond $response
            }
            json set rcontent status ok
            json nest rcontent user_expressions [json new]
        }
        json set rcontent execution_count $exec_counter

        respond [jmsg::reply $jmsg execute_reply $rcontent]
        respond [jmsg::status $ph idle]
    }

    proc respond {jmsg} {
        variable master
        thread::send -async $master [list ::tclkernel::respond $jmsg]
    }

    # Prepare the worker thread: redirect output and create the user interpreter
    proc init {master_id} {
        variable master
        set master $master_id
        chan push stdout {::sessionclient::writechan stdout}
        chan push stderr {::sessionclient::writechan stderr}
        interp create child
        interp alias child ::jupyter::display {} ::sessionclient::display
        interp alias child ::jupyter::updatedisplay {} ::sessionclient::updatedisplay
        interp alias child ::jupyter::complete child ::jupyter::defaultcomplete
        child eval {
            namespace eval jupyter {
                proc defaultcomplete {code pos} {
                    return [list {} $pos]
                }
                proc html {body} {
                    return [display text/html $body]
                }
                proc updatehtml {id body} {
                    return [updatedisplay $id text/html $body]
                }
                namespace export display updatedisplay html updatehtml
            }
        }
    }

    # Run a request handler, reporting errors (and interrupts) back to the client
    proc dispatch_request {type jmsg} {
        if {[catch {$type $jmsg} result]} {
            report_error $jmsg
        }
    }
}
