package require tmq
package require Thread
package require jmsg


set script [file normalize [info script]]
set modfile [file root [file tail $script]]
lassign [split $modfile -] _ modver

interp alias {} pputs {} puts -nonewline


set conn {}
set kernel_id  [uuid::uuid generate]

array set ports {}
set sessions {}
set t {}

proc connect {connection_file} {
    variable conn
    variable ports 
    set f [open $connection_file]
    set conn [read $f]
    close $f
    set key [json get $conn key]
    puts $conn

    interp alias {} hmac {}  sha2::hmac -hex -key $key 

    listen shell ROUTER
    listen control ROUTER
    listen stdin ROUTER
    listen iopub PUB
    listen hb HEARTBEAT

    start [pid]
}

proc respond {name jmsg} {
    variable key
    variable kernel_id
    dict with jmsg {
        json set header session $kernel_id
        set hmac [hmac "[encoding convertto utf-8 $header$parent$metadata$content]"]
        puts "HMAC: calculating for: [encoding convertto utf-8 $header$parent$metadata$content]\nHMAC: $hmac\nHMAC: [interp alias {} hmac]"
    }
    set zmsg [jmsg::znew $jmsg]
    if {$name eq "iopub"} {
        set msg_type [jmsg::msg_type $jmsg]
        set zmsg [linsert $zmsg 0 $msg_type]
    }
    puts "RESPOND to $name:\n[string range [join $zmsg \n] 0 1200]\n"
    if {[catch {tmq::send $name $zmsg}]} {exit -1}
}

proc on_recv {jmsg} {
    variable t
    set session [jmsg::session $jmsg]
    set msg_type [jmsg::msg_type $jmsg]
    set name [jmsg::name $jmsg]
    puts "on_recv $jmsg"
    if {$msg_type eq "kernel_info_request"} {
        handle_info_request $jmsg
        return
    }
    if {$msg_type eq "comm_info_request"} {
        # Unsupported
        return
    }
    if {$name eq "control"} {
        handle_control_request $jmsg
        return
    } 

    # puts ">>>>>>>>>>>>>>>>>>>>"
    # puts $jmsg

    # wrap command in a catch to capture and handle interrupt messages
    thread::send -async $t [list set cmd [list $msg_type $jmsg $t]]
    thread::send -async $t {
        lassign $cmd msg_type jmsg t
        if {[catch {$msg_type $jmsg} result]} {
            bgerror $jmsg $::errorInfo
            # puts $::errorInfo
        }
    }
}



proc start {pid} {
    variable t
    set t [thread::create]
    puts "Created thread $t for $pid"
    thread::send $t [list set master [thread::id]]
    thread::send $t [list set auto_path $::auto_path]
    thread::send $t [list tcl::tm::path add {*}[tcl::tm::path list]]
    thread::send $t {
        package require sessionclient
        chan push stdout {writechan stdout} 
        chan push stderr {writechan stderr} 
        interp create slave
        interp alias slave ::jupyter::display {} display
        interp alias slave ::jupyter::updatedisplay {} updatedisplay
        interp alias slave ::jupyter::complete slave ::jupyter::defaultcomplete
        slave eval {
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
}


proc listen_loop port {
  on_recv $port
  after 500 [list listen_loop $port]
}

proc listen {port type} {
    tmq::listen $port $type [address $port] [namespace code [list on_recv $port]]
}

proc address {port} {
    variable conn
    set address [list transport [json get $conn transport]]
    dict set address channel $port
    dict set address ip [json get $conn ip]
    dict set address port [json get $conn ${port}_port]
    return $address
}

proc handle_control_request {jmsg} {
    set shutdown 0
    variable t
    set ph [dict get $jmsg header]
    set ps [jmsg::session $jmsg]
    set channel [jmsg::channel $jmsg]
    set msg_type [json get $ph msg_type]
    set reply_type {}
    switch -exact $msg_type {
        shutdown_request {
            set shutdown 1
            set reply_type shutdown_reply
        }
        interrupt_request {
            set reply_type interrupt_reply
            puts "Interrupting kernel [pid]"
            thread::cancel  $t
        }
    }
    dict with jmsg {
        set parent $ph
        json set header msg_type $reply_type
    }
    respond control $jmsg
    if {$shutdown} {
        puts "Shutting down kernel [pid]"
        after 0 exit
    }
}

proc handle_info_request {jmsg} {
    puts "Handling info request: $jmsg"
    variable modver
    set parent [dict get $jmsg header]
    set channel [dict get $jmsg channel]
    respond iopub [jmsg::status $parent busy]
    dict with jmsg {
        set parent $header
        set username [json get $header username]
        set header  [jmsg::newheader $username kernel_info_reply] 
        set version [info patchlevel]
	set banner [format "Tcl %s :: TclJupyter kernel %s \nProtocol v%s" \
			$version \
			$modver \
			"5.3"]
        set content [json template $::kernel_info]
    }
    respond shell $jmsg
    respond iopub [jmsg::status $parent idle]
}
set kernel_info { {
    "status" : "ok",
    "protocol_version": "5.3",
    "implementation": "tcljupyter",
    "implementation_version": "~S:modver",
    "language_info": {
        "name": "tcl",
        "version": "~S:version",
        "mimetype": "txt/x-tcl",
        "file_extension": ".tcl"
    },
    "banner" : "~S:banner"
}}


