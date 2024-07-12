#!/bin/bash
set -x

export JUPYTER_CONFIG_DIR=${CONFIG}

# Create a configfile in /config if it doesn't exist
if [ ! -f ${CONFIG}/jupyter_lab_config.py ]; then
	${VENV}/bin/jupyter-lab --generate-config
fi

${VENV}/bin/jupyter-lab --ip=0.0.0.0 --port=${PORT} --no-browser \
  --notebook-dir=${NOTEBOOKS} --allow-root
