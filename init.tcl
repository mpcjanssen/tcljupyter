tcl::tm::path add [file join [file dirname [info script]] modules]
lappend auto_path [file join [file dirname [info script]] libs-$tcl_platform(platform)]
puts $auto_path

package require Tcl 8.6
package require tclkernel
lassign $argv connection_file
connect $connection_file
vwait forever

