.PHONY: test

test:
	@set -eu; \
	kernels_dir=$$(mktemp -d); \
	trap 'rm -rf "$$kernels_dir"' EXIT; \
	mkdir -p "$$kernels_dir/kernels/tcljupyter"; \
	tclsh=$${TCLSH:-$$(command -v tclsh9.0 || command -v tclsh)}; \
	printf '{"argv":["%s","%s/init.tcl","{connection_file}"],"display_name":"Tcl","language":"tcl","interrupt_mode":"message"}\n' \
		"$$tclsh" "$$(pwd)" > "$$kernels_dir/kernels/tcljupyter/kernel.json"; \
	JUPYTER_PATH="$$kernels_dir" uv run python -m tests.test_tcljupyter