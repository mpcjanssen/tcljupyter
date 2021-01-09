package require zmq
package require rl_json
package require jmsg

namespace import rl_json::json

    proc busy {header} {
         set msg [jmsg::status $header busy]
         puts "$::me >>> busy"
         jmsg::send $msg $::key zsocket
    }
    proc idle {header} {
         set msg [jmsg::status $header idle]
         puts "$::me >>> idle"
         jmsg::send $msg $::key zsocket

    }

    proc stream {header name text} {
         puts "$::me >>> stream to $name"

         set response [jmsg::newiopub $header stream]
         dict with response {
        set content [json template {
            {
                "name":"~S:name",
                "text":"~S:text"
            }
        }]
        }
        jmsg::send $response $::key zsocket
        }


proc start {address key} {
set ::key $key
set ::me "iopub([pid])"
zmq context context

zmq socket zsocket context PUB
zsocket bind $address
vwait forever

}




