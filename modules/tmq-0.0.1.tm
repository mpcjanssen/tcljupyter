namespace eval zmtp {
  proc greeting {} {
    set greeting [binary decode hex [join [subst {
      ff00000000000000017f
      03
      01
      [binary encode hex NULL]
      [string repeat 00 16]
      00
      [string repeat 00 31]
      }] ""]]

      if {[string length $greeting] != 64} {
        error "Invalid greeting constant [string length $greeting] <> 64"
      }
      return $greeting
    }

    proc display {data {showascii 0}} {
      set decoded {}

      foreach x [split $data ""] {
        binary scan $x c d
        if {$d < 32 || $d > 126 || !$showascii}  {
          append decoded \\x[binary encode hex $x]
        } {
          append decoded $x
        }

      }
      return $decoded
    }

    proc negotiate {channel} {
      set greeting [greeting]
      fconfigure $channel -blocking 1 -encoding binary -translation binary
      # Negotiate version
      puts -nonewline $channel [string range $greeting 0 10]
      flush $channel
      set remote_greeting [read $channel 11]
      # puts "Remote greeting [display $remote_greeting]"
      # Send rest of greeting
      puts -nonewline $channel [string range $greeting 11 end]
      flush $channel
      append remote_greeting [read $channel [expr {64-11}]]
      puts "Remote greeting [display $remote_greeting]"
    }

    proc handshake {socket zmqtype} {
      set zmqtype [string toupper $zmqtype]
      lassign [readzmsg $socket] type frames
      sendzmsg $socket cmd [list \x05READY\x0bSocket-Type[len32 $zmqtype]$zmqtype\x08Identity[len32 ""]]
  
    }

    proc connection {zmqtype frame_cb channel ip port} {
      puts "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@\nIncoming connection from $channel ($ip:$port) on $zmqtype socket"
      negotiate $channel
      handshake $channel $zmqtype
      fileevent $channel readable [namespace code  [list handle $channel $zmqtype $frame_cb]] 
    }

    proc zframe {ztype frame} {
      set length [string length $frame]
      if {$length > 255} {
        set format W
      } else {
        set format c
      }
      set lengthbytes [binary format $format $length]
      switch -exact $ztype-$format {
        cmd-W {return \x06$lengthbytes$frame}
        cmd-c {return \x04$lengthbytes$frame}
        msg-more-W {return \x03$lengthbytes$frame}
        msg-more-c {return \x01$lengthbytes$frame}
        msg-last-W {return \x02$lengthbytes$frame}
        msg-last-c {return \x00$lengthbytes$frame}
        default {
          return -code error "Invalid message prefix $ztype-$more"
        }
      }
    }

    proc sendzmsg {socket ztype frames} {
      puts "-------------------------------------"
      puts ">>>>> $ztype frames: [llength $frames]"
      foreach f $frames {
          puts [zmtp::display $f 1]
      }
      # on the wire format is UTF-8
      puts " >>> $socket"
      if {$ztype eq "cmd"} {
        if {[llength $frames]!=1} {
          return -error "zmq commands can only have one frame"
        }
        set zframe [zframe cmd [lindex $frames 0]]
        puts " >>> cmd [display $zframe]"
        puts -nonewline $socket $zframe
        catch {flush $socket}
        return
      }
      foreach frame [lrange $frames 0 end-1] {
        set zframe [zframe msg-more $frame]
        puts " >>> msg-more [display $zframe]"
        puts -nonewline $socket $zframe
        catch {flush $socket}
      }
      set frame [lindex $frames end]
      set zframe [zframe msg-last $frame]
      puts " >>> msg-last [display $zframe]"
      puts -nonewline $socket $zframe
      catch {flush $socket}
    }


    proc readzmsg {socket} {
      puts "-------------------------------------"
      set more 1
      set frames {}
          puts " <<< $socket"
      while {$more} {


        set prefix [read $socket 1]
          if {[eof $socket]} {
          puts "xxxxxxx: Socket $socket closed"
          fileevent $socket readable {}
          return
      }

        switch -exact $prefix {
          \x00 {
            set zmsg_type msg-last
            set more 0
            set size short
          }
          \x01 {
            set zmsg_type msg-more
            set more 1
            set size short
          }
          \x02 {
            set zmsg_type msg-last
            set more 0
            set size long
          }
          \x03 {
            set zmsg_type msg-more
            set more 1
            set size long
          }
          \x04 {
            set zmsg_type cmd
            set more 0
            set size short
          }
          \x06 {
            set zmsg_type cmd
            set more 0
            set size long
          }
          default {
            close $socket
            return -code error "ERROR: Unknown frame start [display $prefix 0]"
          }
        }
        if {$size eq "short"} {
          set length [read $socket 1]
          binary scan $length c bytelength
          set bytelength [expr { $bytelength & 0xff }]
        } {
          set length [read $socket 8]
          binary scan $length W  bytelength
        }
        set frame [read $socket $bytelength]

        puts " <<< $zmsg_type [display $prefix$length$frame]"
        lappend frames $frame
      }
             puts "<<<<< [lindex [split $zmsg_type -] 0] frames: [llength $frames]"
      foreach f $frames {
          puts [zmtp::display $f 1]
     }
       puts +++++++++++++++++$zmsg_type
      return [list [lindex [split $zmsg_type -] 0] $frames]
    }


    proc handle {socket zmqtype frame_cb} {
        lassign [readzmsg $socket] zmsgtype frames
        puts ------------------$zmsgtype
        $frame_cb $socket $zmsgtype $frames
    }
    proc zlen {str} {
      if {[string length $str] < 256} {
        return \x04[len8 $str]
      } else {
        return \x06[len32 $str]
      }
    }

    proc len32 {str} {
      return [binary format I [string length $str]]
    }
    proc len8 {str} {
      return [binary format c [string length $str]]
    }
  }

  namespace eval zmq {
    proc bind {type port frame_cb} {
      socket -server [list zmtp::connection $type $frame_cb] $port
    }
  }
