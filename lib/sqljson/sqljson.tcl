package require sqlite3

namespace eval ::sqljson {
    namespace export decode get str num bool null object array
    namespace ensemble create
    sqlite3 [namespace current]::db :memory:
}

# JSON text -> Tcl value: objects become dicts, arrays lists, null "".
proc ::sqljson::decode {json} {
    if {[string trim $json] eq ""} {
        return ""
    }
    set type [db onecolumn {SELECT json_type(CAST(:json AS TEXT))}]
    if {$type in {object array}} {
        return [Convert $json $type]
    }
    Convert [db onecolumn {SELECT json_extract(CAST(:json AS TEXT), '$')}] $type
}

proc ::sqljson::Convert {value type} {
    switch -- $type {
        object {
            set result [dict create]
            db eval {SELECT key AS k, value AS v, type AS t FROM json_each(:value)} {
                dict set result $k [Convert $v $t]
            }
            return $result
        }
        array {
            set result {}
            db eval {SELECT value AS v, type AS t FROM json_each(:value)} {
                lappend result [Convert $v $t]
            }
            return $result
        }
        true    { return true }
        false   { return false }
        null    { return "" }
        default { return $value }
    }
}

# Extract a value by path (e.g. items[0].name or [2]); the leading "$" of the
# SQLite JSON path is implicit and an empty path is the whole document.
# Nested values stay JSON text.
proc ::sqljson::get {json path} {
    if {$path eq "" || [string index $path 0] eq "\["} {
        set path \$$path
    } else {
        set path \$.$path
    }
    db onecolumn {SELECT json_extract(CAST(:json AS TEXT), :path)}
}

proc ::sqljson::str {s} {
    db onecolumn {SELECT json_quote(CAST(:s AS TEXT))}
}

proc ::sqljson::num {n} {
    if {![regexp {^-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?$} $n]} {
        return -code error -errorcode {SQLJSON NUMBER} "not a JSON number: \"$n\""
    }
    return $n
}

proc ::sqljson::bool {b} {
    if {$b} { return true }
    return false
}

proc ::sqljson::null {} {
    return null
}

# Values must already be JSON text (use str/num/bool/null/object/array).
proc ::sqljson::object {args} {
    if {[llength $args] % 2} {
        return -code error "wrong # args: should be \"object ?key value ...?\""
    }
    set parts {}
    foreach {k v} $args {
        lappend parts "[str $k]:$v"
    }
    Validate "\{[join $parts ,]\}"
}

proc ::sqljson::array {args} {
    Validate "\[[join $args ,]\]"
}

proc ::sqljson::Validate {text} {
    if {![db onecolumn {SELECT json_valid(:text)}]} {
        return -code error -errorcode {SQLJSON INVALID} "invalid JSON: $text"
    }
    db onecolumn {SELECT json(:text)}
}
package provide sqljson 0.1