# Lessons learned

- This repo is not a Python package. `pyproject.toml` uses `[tool.uv] package = false`; uv only manages `.venv` and test dependencies. Don't add a `[build-system]` or `[project.scripts]`.
- Tests: `make test` (Unix) or `make -f Makefile.win test` (Windows). Both generate a temporary `kernel.json` and point `JUPYTER_PATH` at it; no installed kernel is needed.
- Skipped tests in `tests/test_tcljupyter.py` are expected: `jupyter_kernel_test` skips tests for optional features whose class attributes (completion, inspect, errors, ...) are not set.
- `make install` / `scripts/install.ps1` only write `kernel.json` and `logo-svg.svg` into the Jupyter kernels dir. `kernel.json` points at `init.tcl` in the repo, which finds the Tcl packages in `lib/` relative to itself (each package has its own `lib/<name>/pkgIndex.tcl`). They refuse to run if the target dir already exists.
- Windows: `make.exe` with PowerShell as `SHELL` breaks on multi-line recipes (quoting, `.ONESHELL`). Keep logic in `.ps1` scripts and have `Makefile.win` just call them.
- `Untitled*.ipynb` is gitignored; don't commit scratch notebooks.
- Before committing, check `git status` first and avoid `git add -A` so unrelated notebook changes aren't included.
- Before repository work, verify the current project tree and active package/source resolution; prior paths and workspace context may be stale after a pull or branch change.
- Architecture: `lib/tclkernel` runs in the main thread (ZMQ sockets, heartbeat, routing); user code runs in a worker thread (`lib/sessionclient`) inside a `child` interpreter. The worker sends replies back with `thread::send` to `::tclkernel::respond`. Keep package code in its own namespace (`::tclkernel`, `::sessionclient`, `::logging`).
- In the worker thread `stdout`/`stderr` are redirected into notebook output. Anything that must not appear in cells (log/trace output) has to go through `logging::*`, which forwards to the main thread (`logging::forward_to`).
- Logging: set `TCLJUPYTER_LOGLEVEL` to `TRACE`, `DEBUG`, `INFO` (default) or `NONE`. `logging::trace|debug|log` take a script, evaluated only when enabled; don't leave commented-out `puts` debugging.
- JSON is built with SQLite (`lib/jlib`): a Tcl integer or double is emitted as a JSON number, and notebooks then fail with "Notebook JSON is invalid ... is not valid under any of the given schemas". Wrap user-supplied text fields (results, stream text, display data, error values) in `json str`; leave real numbers like `execution_count` alone. `format %s` does not help.
- Build replies with `jmsg::reply jmsg type content` and `jmsg::status`; don't copy the header/parent boilerplate.
- `gets stdin` is overridden in the child interpreter to send an `input_request` on the stdin socket and `vwait` for the `input_reply` (needs `allow_stdin`). `read stdin` is not covered.
- Tracked notebooks in `notebooks/` change whenever they're run. They are marked `skip-worktree` locally (per clone, not shared); `git pull` may need `git update-index --no-skip-worktree <file>` first.
