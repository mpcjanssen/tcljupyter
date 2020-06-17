tcl::tm::path add [file join [file dirname [info script]] modules]
lappend auto_path [file join [file dirname [info script]] libs-$tcl_platform(platform)]

package require Tcl 8.6
package require tclkernel
if {[llength $argv] == 0} {
  puts $auto_path
  puts [package require Thread]
  puts [package require rl_json]
  puts [package require zmq]
  exit 1
}
lassign $argv connection_file
puts ">>>>>>>>>>>>>>>>>>>>>>>>> Kernel started, pid: [pid] <<<<<<<<<<<<<<<<<<<<<<<<<"
connect $connection_file

vwait forever

