.PHONY: test

test:
	@set -eu; \
	kernels_dir=$$(mktemp -d); \
	trap 'rm -rf "$$kernels_dir"' EXIT; \
	mkdir -p "$$kernels_dir/kernels/tcljupyter"; \
	cp kernel.json.test "$$kernels_dir/kernels/tcljupyter/kernel.json"; \
	JUPYTER_PATH="$$kernels_dir" uv run python -m tests.test_tcljupyter