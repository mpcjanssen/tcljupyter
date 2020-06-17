

## Installation

Manually copy to a subdirectory of the kernels directory in a Jupyter data location (one of `jupyter --paths`). See the `kernel.json.win` or `kernel.json.linux` files for example paths.

Copy one of the `kernel.json....` files to `kernel.json`.
Then change the paths in `kernel.json` to match your machine.

Jupyter will use the `kernel.json` file to start the kernel (passing the connection file as the first parameter).

### Binder

If you want to try it out without installation you can use the Binder version in the cloud.

[![Binder](https://mybinder.org/badge_logo.svg)](https://mybinder.org/v2/gh/mpcjanssen/tcljupyter/master?filepath=examples%2Fexample.ipynb)

### Dependencies

The tcl used to run the `init.tcl` script should have the following available:

- Tcl 8.6 with threads
- [tclzmq](https://github.com/jdc8/tclzmq) 
- [rl_json](https://github.com/RubyLane/rl_json) 0.11.0 or higher
- [tcllib](https://core.tcl-lang.org/tcllib/doc/trunk/embedded/index.md) uuid
- [tcllib](https://core.tcl-lang.org/tcllib/doc/trunk/embedded/index.md) sha256



## Supported

Most web client commands are supported. Only thing missing is reading from stdin with for example `gets`. 

### Commands

   * `jupyter::display mimetype body`: Display body in the cell. Returns the display id for use in `updatedisplay`.
   * `jupyter::html body`: Display body as html in the cell. Returns the display id for use in `updatedisplay`. 
   * `jupyter::updatedisplay id mimetype body`: Updates the display with id `id` with then new body.
   * `jupyter::updatehtml id body`: Updates the html display with id `id` with the new body.


If a cell ends with `;` the last result is not displayed.

## Design

![Design](https://plantuml.mpcjanssen.nl/png/TOx12eCm44Jl-Oh5kpyWfPUSGexnA9H5bnf8rpIR2ltxrYXM3xtEl7bCn9HzxoDoXae7JvmxTYJY9wu01RHJySXOIaoXLFRSRAkEsp4H3WLnxH_6SAOKLyOefHtKzHKiD93e-IB9IjaIkRQ14Na8T7l8NRaMbj0qG3C6XNtsCsPQ9CxiWy5B3FWkzABz9QjKkmDZO5ibabV8Qg2JTLTizVVgfQwtgn8d5le0)

For communication from kernel to session thread [thread::send -async] is being used. `stdout` and `stderr` are being intercepted by `chan push`


