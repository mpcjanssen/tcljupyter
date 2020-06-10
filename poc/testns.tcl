package require Thread

set t [thread::create]

thread::send -async $t "interp create slave ; slave eval {package require http}; thread::wait "
thread::send -async $t "slave eval {http::geturl http://www.google.com}"

thread::send -async $t {slave eval {puts [namespace current]}}
vwait forever