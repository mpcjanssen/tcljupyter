package require sqlite3

set log [open log.txt a]
fconfigure $log -buffering line

puts $log "started"

namespace eval json {

    namespace ensemble create -map [list get get set jset new new nest nest arr arr]
    sqlite3 db
    proc get {str key} {
        set path "\$.$key"
        lassign [db eval {select json_extract($str, $path)}] val
        return $val
    }

    proc new {args} {
        set js "{}"
        foreach {k v} $args {
            set path "\$.$k"
            lassign [db eval {select json_set($js,$path,$v)}] js
        }
        return $js
    }
    proc jset {varname k v} {
        puts $::log "set\t$varname: $k->$v"
        upvar $varname str
         puts $::log [info exists str]
        set path "\$.$k"
        lassign  [db eval {select json_set($str,$path,$v)}] js
        set str $js
    }

    proc nest {varname k jv} {
        upvar $varname str
        puts $::log "nest:\t$varname: $k->$jv"
        set path "\$.$k"
        if {[catch {lassign  [db eval {select json_set($str,$path,json($jv))}] js}]} {
            puts $::log ERROR
            puts $::log [info exists str]
            puts $::log [info level 0]
            puts $::log $str
            puts $::log $::errorInfo
            puts $::log END

        }
        
        set str $js
    }

    proc arr {args} {
        set js {[]}
        foreach v $args {
            lassign [db eval {select json_insert($js,'$[#]',$v)} ] js 
        }
        return $js
    }

}