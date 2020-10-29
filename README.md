

## Installation

Manually copy to a subdirectory of the kernels directory in a Jupyter data location (one of `jupyter --paths`). See the `kernel.json.win` or `kernel.json.linux` files for example paths.

Copy one of the `kernel.json....` files to `kernel.json`.
Then change the paths in `kernel.json` to match your machine.

Jupyter will use the `kernel.json` file to start the kernel (passing the connection file as the first parameter).

### Binder

If you want to try it out without installation you can use the Binder version in the cloud.

[![Binder](https://mybinder.org/badge_logo.svg)](https://mybinder.org/v2/gh/mpcjanssen/tcljupyter/binder?filepath=examples%2Fexample.ipynb)

### Dependencies

The Tcl used to run the `init.tcl` script should have the following available:

- Tcl 8.6 with threads
- [tclzmq](https://github.com/jdc8/tclzmq) 
- [rl_json](https://github.com/RubyLane/rl_json) 0.11.0 or higher
- [tcllib](https://core.tcl-lang.org/tcllib/doc/trunk/embedded/index.md) uuid
- [tcllib](https://core.tcl-lang.org/tcllib/doc/trunk/embedded/index.md) sha256

### Build tclzmq on windows

Easiest way to build tclzmq on Windows is to use mingw.

- Install tcllib
- Install critcl
- Install the msys zmq packages

```
pacman -Syu mingw64/mingw-w64-x86_64-gcc mingw64/mingw-w64-x86_64-zeromq
```
- Run the `build.tcl` installer from the tclzmq distro. NB: Static builds don't work in the sense that they are the same as shared builds.


## Supported

Most web client commands are supported. Only thing missing is reading from stdin with for example `gets`. 

### Commands

   * `jupyter::display mimetype body`: Display body in the cell. Returns the display id for use in `updatedisplay`.
   * `jupyter::html body`: Display body as html in the cell. Returns the display id for use in `updatedisplay`. 
   * `jupyter::updatedisplay id mimetype body`: Updates the display with id `id` with then new body.
   * `jupyter::updatehtml id body`: Updates the html display with id `id` with the new body.


If a cell ends with `;` the last result is not displayed.

## Test suite

A prequisite is the [jupyter_kernel_test](https://github.com/jupyter/jupyter_kernel_test) (JKT) module:

`pip install jupyter_kernel_test`

To run the test suite, execute (from within the checkout directory):

`python -m tests.test_tcljupyter`


## Design

![Design](http://www.plantuml.com/plantuml/png/TOx12eCm44Jl-Oh5kpyWfPUSGexnA9H5bnf8rpIR2ltxrYXM3xtEl7bCn9HzxoDoXae7JvmxTYJY9wu01RHJySXOIaoXLFRSRAkEsp4H3WLnxH_6SAOKLyOefHtKzHKiD93e-IB9IjaIkRQ14Na8T7l8NRaMbj0qG3C6XNtsCsPQ9CxiWy5B3FWkzABz9QjKkmDZO5ibabV8Qg2JTLTizVVgfQwtgn8d5le0)

For communication from kernel to session thread [thread::send -async] is being used. `stdout` and `stderr` are being intercepted by `chan push`


