#!/bin/bash
set -x

export JUPYTER_CONFIG_DIR=${CONFIG}

# Create a configfile in /config if it doesn't exist
if [ ! -f ${CONFIG}/jupyter_lab_config.py ]; then
	jupyter-lab --generate-config
fi

jupyter-lab --ip=0.0.0.0 --port=${PORT} --no-browser \
  --notebook-dir=${NOTEBOOKS}
