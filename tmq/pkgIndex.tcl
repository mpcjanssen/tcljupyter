package ifneeded tmq 1.0 [list apply {dir { 
    uplevel 1 [list source [file join $dir messaging.tcl]] 
    package provide tmq 1.0
}} $dir]