

namespace eval tmq {
     set mod_dir [file dirname [info script]]
     proc serve {ztype port alias callback} {
          variable mod_dir
          set ztype [string tolower $ztype]
          puts "$ztype socket on $port"
          set interp [interp create]
          $interp eval [list source [file join $mod_dir utils.tcl]]
          $interp eval [list source [file join $mod_dir ${ztype}.tcl]]
          $interp eval [list start $port $alias]
          interp alias $interp on_recv {} $callback
          interp alias {} $alias $interp on_cmd

     }




}


