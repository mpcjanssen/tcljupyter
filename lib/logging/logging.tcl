package provide logging 0.0.1

# Levels are selected with the TCLJUPYTER_LOGLEVEL environment variable:
#   TRACE: log, debug and trace output
#   DEBUG: log and debug output
#   INFO:  log output only (default)
#   NONE:  no output
# All commands take a script that is evaluated in the caller's scope only
# when the level is enabled, so disabled messages cost nothing to build.
namespace eval logging {
    variable level INFO
    if {[info exists ::env(TCLJUPYTER_LOGLEVEL)]} {
        set level [string toupper $::env(TCLJUPYTER_LOGLEVEL)]
    }

    # In the worker thread stderr is redirected to the notebook, so output
    # is forwarded to this thread instead (see forward_to)
    variable forward {}

    proc forward_to {thread_id} {
        variable forward
        set forward $thread_id
    }

    proc emit {script} {
        variable forward
        set text [uplevel 1 $script]
        if {$forward eq {}} {
            puts stderr $text
        } else {
            thread::send -async $forward [list puts stderr $text]
        }
    }

    proc noop {script} {}

    # Enable each command whose threshold is at or below the current level
    set rank {TRACE 0 DEBUG 1 INFO 2 NONE 3}
    if {![dict exists $rank $level]} {
        set level INFO
    }
    foreach {cmd threshold} {trace 0 debug 1 log 2} {
        if {[dict get $rank $level] <= $threshold} {
            interp alias {} ::logging::$cmd {} ::logging::emit
        } else {
            interp alias {} ::logging::$cmd {} ::logging::noop
        }
    }
}
