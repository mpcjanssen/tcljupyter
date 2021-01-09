package require zmq
package require rl_json
package require jmsg

namespace import rl_json::json

proc start {port} {
zmq context context

zmq socket zsocket context PUB
zsocket bind $port


}



