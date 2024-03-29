#!/bin/bash
set -x

export JUPYTER_CONFIG_DIR=$JL_CONFIG

# Create a configfile in /config if it doesn't exist
if [ ! -f ${JL_CONFIG}/jupyter_lab_config.py ]; then
	${JL_VENV}/bin/jupyter-lab --generate-config
fi

${JL_VENV}/bin/jupyter-lab --ip=0.0.0.0 --port=${JL_PORT} --no-browser \
  --notebook-dir=${JL_DATA} --allow-root
