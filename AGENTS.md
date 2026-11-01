# Lessons learned

- This repo is not a Python package. `pyproject.toml` uses `[tool.uv] package = false`; uv only manages `.venv` and test dependencies. Don't add a `[build-system]` or `[project.scripts]`.
- Tests: `make test` (Unix) or `make -f Makefile.win test` (Windows). Both generate a temporary `kernel.json` and point `JUPYTER_PATH` at it; no installed kernel is needed.
- Skipped tests in `tests/test_tcljupyter.py` are expected: `jupyter_kernel_test` skips tests for optional features whose class attributes (completion, inspect, errors, ...) are not set.
- `make install` / `scripts/install.ps1` only write `kernel.json` and `logo-svg.svg` into the Jupyter kernels dir. `kernel.json` points at `init.tcl` in the repo, which finds the Tcl packages in `lib/` relative to itself (each package has its own `lib/<name>/pkgIndex.tcl`). They refuse to run if the target dir already exists.
- Windows: `make.exe` with PowerShell as `SHELL` breaks on multi-line recipes (quoting, `.ONESHELL`). Keep logic in `.ps1` scripts and have `Makefile.win` just call them.
- `Untitled*.ipynb` is gitignored; don't commit scratch notebooks.
- Before committing, check `git status` first and avoid `git add -A` so unrelated notebook changes aren't included.
- Before repository work, verify the current project tree and active package/source resolution; prior paths and workspace context may be stale after a pull or branch change.
