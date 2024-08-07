# Index file to load the TDBC SQLite3 package.

package ifneeded tdbc::sqlite3 1.1.8 \
    [list source -encoding utf-8 [file join $dir .. library tdbcsqlite3.tcl]]
