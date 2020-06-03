namespace eval tclkernel {
    proc connect {connection_file} {	
	set f [open $connection_file]
	puts [read $f]
	close $f
    }
}

