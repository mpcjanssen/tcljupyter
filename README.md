

## Installation

Manually copy to a Jupyter data location `jupyter --paths`.

Then change the paths in `kernel.json` to match your machine.

### Dependencies

The tcl used to run the `init.tcl` script should have the following available:

- Tcl 8.6 with threads
- [tclzmq](https://github.com/jdc8/tclzmq) 
- [rl_json](https://github.com/RubyLane/rl_json) 0.11.0 or higher
- [tcllib](https://core.tcl-lang.org/tcllib/doc/trunk/embedded/index.md) uuid
- [tcllib](https://core.tcl-lang.org/tcllib/doc/trunk/embedded/index.md) sha256



## Supported

Most web client commands are supported. Only thing missing is reading from stdin with for example `gets`. 
Also interrupting the kernel will display the interruption message under the currently active cell (not the interrupted one).


### Commands

   * `jupyter::display mimetype body`: Display body in the cell. Returns the display id for use in `updatedisplay`.
   * `jupyter::html body`: Display body as html in the cell. Returns the display id for use in `updatedisplay`. 
   * `jupyter::updatedisplay id mimetype body`: Updates the display with id `id` with then new body.
   * `jupyter::updatehtml id body`: Updates the html display with id `id` with then new body.


If a cell ends with `;` the last result is not displayed.

## Design

![Design](https://plantuml.mpcjanssen.nl/png/TOx12eCm44Jl-Oh5kpyWfPUSGexnA9H5bnf8rpIR2ltxrYXM3xtEl7bCn9HzxoDoXae7JvmxTYJY9wu01RHJySXOIaoXLFRSRAkEsp4H3WLnxH_6SAOKLyOefHtKzHKiD93e-IB9IjaIkRQ14Na8T7l8NRaMbj0qG3C6XNtsCsPQ9CxiWy5B3FWkzABz9QjKkmDZO5ibabV8Qg2JTLTizVVgfQwtgn8d5le0)

For communication from kernel to session thread `[chan pipe]`s are being used. `stdout` and `stderr` are being intercepted by `chan push`


