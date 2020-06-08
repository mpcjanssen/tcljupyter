puts [fconfigure stdout -encoding]

proc writechan {chan cmd args} {
switch -exact $cmd {
    initialize { return {initialize finalize write flush}}

    write {
	lassign $args handle buffer
	set text [encoding convertfrom [fconfigure stdout -encoding] $buffer]
 	puts stderr $text
	return $buffer
    }
}
}
chan push stdout {writechan stdout}

puts testing