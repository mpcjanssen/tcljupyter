.PHONY: test install

# Override with e.g. `make install KERNEL_DIR=~/.local/share/jupyter/kernels/tcljupyter`
DATA_DIR = $(shell uv run jupyter --data-dir)
KERNEL_DIR ?= $(DATA_DIR)/kernels/tcljupyter

install:
	@set -eu; \
	tclsh=$${TCLSH:-$$(command -v tclsh9.0 || command -v tclsh)}; \
	mkdir -p "$(KERNEL_DIR)"; \
	cp logo-svg.svg "$(KERNEL_DIR)/"; \
	printf '{"argv":["%s","%s/init.tcl","{connection_file}"],"display_name":"Tcl","language":"tcl","interrupt_mode":"message"}\n' \
		"$$tclsh" "$$(pwd)" > "$(KERNEL_DIR)/kernel.json"; \
	echo "Installed tcljupyter kernel to $(KERNEL_DIR)"

test:
	@set -eu; \
	kernels_dir=$$(mktemp -d); \
	trap 'rm -rf "$$kernels_dir"' EXIT; \
	mkdir -p "$$kernels_dir/kernels/tcljupyter"; \
	tclsh=$${TCLSH:-$$(command -v tclsh9.0 || command -v tclsh)}; \
	printf '{"argv":["%s","%s/init.tcl","{connection_file}"],"display_name":"Tcl","language":"tcl","interrupt_mode":"message"}\n' \
		"$$tclsh" "$$(pwd)" > "$$kernels_dir/kernels/tcljupyter/kernel.json"; \
	JUPYTER_PATH="$$kernels_dir" uv run python -m tests.test_tcljupyter