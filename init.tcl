tcl::tm::path add [file join [file dirname [info script]] modules]
lappend auto_path [file join [file dirname [info script]] libs-$tcl_platform(platform)]

package require Tcl 8.6
package require zmq
package require tclkernel
lassign $argv connection_file
tclkernel::connect $connection_file

