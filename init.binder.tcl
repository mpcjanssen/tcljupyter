tcl::tm::path add [file join [file dirname [info script]] modules]
lappend auto_path [file join [file dirname [info script]] libs-$tcl_platform(platform)]
lappend auto_path /srv/conda/envs/notebook/lib

package require Tcl 8.6
package require tclkernel
lassign $argv connection_file
puts ">>>>>>>>>>>>>>>>>>>>>>>>> Kernel started, pid: [pid] <<<<<<<<<<<<<<<<<<<<<<<<<"
connect $connection_file

vwait forever

