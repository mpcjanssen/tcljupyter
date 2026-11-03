package require sqlite3

namespace eval ::sqljson {
    namespace export decode get isnull jset template str num bool null object array
    namespace ensemble create
    sqlite3 [namespace current]::db :memory:
}

# JSON text -> Tcl value: objects become dicts (keys with a null value are
# omitted), arrays lists (null elements become ""), a top-level null "".
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
                if {$t ne "null"} {
                    dict set result $k [Convert $v $t]
                }
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

# Turn a path such as items[0].name or [2] into a SQLite JSON path; the leading
# "$" is implicit and an empty path is the whole document.
proc ::sqljson::Path {path} {
    if {$path eq "" || [string index $path 0] eq "\["} {
        return \$$path
    }
    return \$.$path
}

# Extract a value by path (e.g. items[0].name or [2]); nested values stay JSON text.
proc ::sqljson::get {json path} {
    set path [Path $path]
    db onecolumn {SELECT json_extract(CAST(:json AS TEXT), :path)}
}

# True if the value at path is JSON null or the path does not exist (decode
# treats both the same, by omitting the key).
proc ::sqljson::isnull {json path} {
    set path [Path $path]
    db onecolumn {SELECT json_type(CAST(:json AS TEXT), :path) IS NULL
        OR json_type(CAST(:json AS TEXT), :path) = 'null'}
}

# Set the value at path in the JSON text held in varname, creating or
# replacing it. The value must already be JSON (use str/num/bool/null/object/array).
# Returns the new JSON text.
proc ::sqljson::jset {varname path value} {
    upvar 1 $varname json
    if {![info exists json] || [string trim $json] eq ""} {
        set json {{}}
    }
    set path [Path $path]
    if {![db onecolumn {SELECT json_valid(:value)}]} {
        return -code error -errorcode {SQLJSON INVALID} "invalid JSON: $value"
    }
    set json [db onecolumn {SELECT json_set(CAST(:json AS TEXT), :path, json(:value))}]
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

# Replace every {{~type:varname}} in text with the JSON encoding of the caller's
# variable varname and return the validated, minified result. Types:
#   str, num, bool  the value as a JSON string, number or boolean
#   null            JSON null; no variable is needed ({{~null}})
#   object          a dict whose values are JSON text
#   array           a list whose elements are JSON text
#   json            the value, which is already JSON text
proc ::sqljson::template {text} {
    set result ""
    set pos 0
    while {[regexp -indices -start $pos {\{\{~(\w+)(?::([^{}]+))?\}\}} $text match type name]} {
        lassign $match from to
        set type [string range $text {*}$type]
        if {$type eq "null"} {
            set value null
        } else {
            if {$name eq "" || [lindex $name 0] < 0} {
                return -code error -errorcode {SQLJSON TEMPLATE} \
                    "template type \"$type\" needs a variable name"
            }
            set name [string range $text {*}$name]
            set value [uplevel 1 [list ::set $name]]
            switch -- $type {
                str    { set value [str $value] }
                num    { set value [num $value] }
                bool   { set value [bool $value] }
                object { set value [object {*}$value] }
                array  { set value [array {*}$value] }
                json   { }
                default {
                    return -code error -errorcode {SQLJSON TEMPLATE} \
                        "unknown template type \"$type\" for variable \"$name\""
                }
            }
        }
        append result [string range $text $pos $from-1] $value
        set pos [expr {$to + 1}]
    }
    append result [string range $text $pos end]
    Validate $result
}

proc ::sqljson::Validate {text} {
    if {![db onecolumn {SELECT json_valid(:text)}]} {
        return -code error -errorcode {SQLJSON INVALID} "invalid JSON: $text"
    }
    db onecolumn {SELECT json(:text)}
}
package provide sqljson 0.1