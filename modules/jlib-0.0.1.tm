package require sqlite3
namespace eval json {

    namespace ensemble create -map [list get get set jset new new nest nest]
    sqlite3 db
    proc get {str key} {
        set path "\$.$key"
        lassign [db eval {select json_extract($str, $path)}] val
        puts js:\t$val
        return $val
    }

    proc new {args} {
        set js "{}"
        foreach {k v} $args {
            set path "\$.$k"
            puts "$js, $path -> $v" 
            lassign [db eval {select json_set($js,$path,$v)}] js
        }
        puts js:\t$js
        return $js
    }
    proc jset {str k v} {
        set path "\$.$k"
        lassign  [db eval {select json_set($str,$path,$v)}] js
        puts js:\t$js
        return $js
    }

    proc nest {str k jv} {
        set path "\$.$k"
        lassign  [db eval {select json_set($str,$path,jsonb($jv))}] js
        puts js:\t$js
        return $js
    }

}