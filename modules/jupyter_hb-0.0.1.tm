package require zmq

proc start {address} {
zmq context context
zmq socket zsocket context REP
zsocket bind $address
zmq device FORWARDER zsocket zsocket
vwait forever
}



