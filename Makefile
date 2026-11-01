.PHONY: test install check-uv

# Override with e.g. `make install KERNEL_DIR=~/.local/share/jupyter/kernels/tcljupyter`
DATA_DIR = $(shell uv run jupyter --data-dir)
KERNEL_DIR ?= $(DATA_DIR)/kernels/tcljupyter

check-uv:
	@command -v uv >/dev/null 2>&1 || { echo "Error: uv not found in PATH. Install it from https://docs.astral.sh/uv/" >&2; exit 1; }

install: check-uv
	@set -eu; \
	if [ -e "$(KERNEL_DIR)" ]; then echo "Error: $(KERNEL_DIR) already exists. Remove it first." >&2; exit 1; fi; \
	tclsh=$${TCLSH:-$$(command -v tclsh9.0 || command -v tclsh)}; \
	mkdir -p "$(KERNEL_DIR)"; \
	cp logo-svg.svg "$(KERNEL_DIR)/"; \
	printf '{"argv":["%s","%s/init.tcl","{connection_file}"],"display_name":"Tcl","language":"tcl","interrupt_mode":"message"}\n' \
		"$$tclsh" "$$(pwd)" > "$(KERNEL_DIR)/kernel.json"; \
	echo "Installed tcljupyter kernel to $(KERNEL_DIR)"

test: check-uv
	@set -eu; \
	kernels_dir=$$(mktemp -d); \
	trap 'rm -rf "$$kernels_dir"' EXIT; \
	mkdir -p "$$kernels_dir/kernels/tcljupyter"; \
	tclsh=$${TCLSH:-$$(command -v tclsh9.0 || command -v tclsh)}; \
	printf '{"argv":["%s","%s/init.tcl","{connection_file}"],"display_name":"Tcl","language":"tcl","interrupt_mode":"message"}\n' \
		"$$tclsh" "$$(pwd)" > "$$kernels_dir/kernels/tcljupyter/kernel.json"; \
	JUPYTER_PATH="$$kernels_dir" uv run python -m tests.test_tcljupyter