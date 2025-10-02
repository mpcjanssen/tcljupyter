package require sqlite3

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
        # puts $::log "set\t$varname: $k->$v"
        upvar $varname str
        if {![info exists str]} {
            set str [json new]
        }
        set path "\$.$k"
        lassign  [db eval {select json_set($str,$path,$v)}] str
    }

    proc nest {varname k jv} {
        upvar $varname str
        # puts $::log "nest:\t$varname: $k->$jv"
        set path "\$.$k"
        lassign  [db eval {select json_set($str,$path,json($jv))}] str
    }

    proc arr {args} {
        set js {[]}
        foreach v $args {
            lassign [db eval {select json_insert($js,'$[#]',$v)} ] js 
        }
        return $js
    }

}