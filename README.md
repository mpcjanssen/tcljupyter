Manually copy to a Jupyter data location `jupyter --paths`.

Then change the paths in `kernel.json` to match your machine.


## Design

![Design](https://plantuml.mpcjanssen.nl/png/TOx12eCm44Jl-Oh5kpyWfPUSGexnA9H5bnf8rpIR2ltxrYXM3xtEl7bCn9HzxoDoXae7JvmxTYJY9wu01RHJySXOIaoXLFRSRAkEsp4H3WLnxH_6SAOKLyOefHtKzHKiD93e-IB9IjaIkRQ14Na8T7l8NRaMbj0qG3C6XNtsCsPQ9CxiWy5B3FWkzABz9QjKkmDZO5ibabV8Qg2JTLTizVVgfQwtgn8d5le0)

For communication from kernel to session thread `[chan pipe]`s are being used. `stdout` and `stderr` are being intercepted by `chan push`


## Dependencies

- Tcl 8.6 with threads
- tclzmq
- rl_json 0.11.0 or higher
- tcllib uuid
- tcllib sha256
