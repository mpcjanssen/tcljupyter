package provide logging 0.0.1

# Levels are selected with the TCLJUPYTER_LOGLEVEL environment variable:
#   DEBUG: log and debug output
#   INFO:  log output only (default)
#   NONE:  no output
# Both commands take a script that is evaluated in the caller's scope only
# when the level is enabled, so disabled messages cost nothing to build.
namespace eval logging {
    variable level INFO
    if {[info exists ::env(TCLJUPYTER_LOGLEVEL)]} {
        set level [string toupper $::env(TCLJUPYTER_LOGLEVEL)]
    }

    proc emit {script} {
        puts stderr [uplevel 1 $script]
    }

    proc noop {script} {}

    switch -exact $level {
        DEBUG {
            interp alias {} ::logging::debug {} ::logging::emit
            interp alias {} ::logging::log {} ::logging::emit
        }
        NONE {
            interp alias {} ::logging::debug {} ::logging::noop
            interp alias {} ::logging::log {} ::logging::noop
        }
        default {
            interp alias {} ::logging::debug {} ::logging::noop
            interp alias {} ::logging::log {} ::logging::emit
        }
    }
}
