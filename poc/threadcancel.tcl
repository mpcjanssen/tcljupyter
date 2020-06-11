package require Thread

set t [thread::create]
thread::send $t {
	
	proc doit {} {
        	catch {
			while 1 {}
		} error
		puts here
		puts zzz$error
	}
}
puts x

puts xx
proc errorproc {args} {puts zzzzzzzz#$args ; exit}
	thread::errorproc errorproc
thread::send -async $t {
	doit	
}

puts [thread::cancel $t]
puts lalal
vwait forever