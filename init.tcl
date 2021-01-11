tcl::tm::path add [file join [file dirname [info script]] modules]
lappend auto_path [file join [file dirname [info script]] libs]


package require Tcl 8.6

if {[llength $argv] == 0} {
  puts [info script]
  puts [glob [file dirname [info script]]/libs/*]
  puts $auto_path
  puts [package require Thread]
  puts [package require rl_json]
  puts [package require tmq]
  exit 1
}
source [file join [file dirname [info script]] tclkernel.tcl]
lassign $argv connection_file
puts ">>>>>>>>>>>>>>>>>>>>>>>>> Kernel started, pid: [pid] <<<<<<<<<<<<<<<<<<<<<<<<<"
connect $connection_file

vwait forever

