#!/usr/bin/env bash

set -eo pipefail

source code/conda_stuff.sh

# Change as needed
export _CONDA_CMD=$(test -z $(which mamba) && echo "conda" || echo "mamba")

echo "Using conda command: $_CONDA_CMD"

export ENVIRONMENT_NAME="paranames-ner" # random name :)

# Create conda environment
$_CONDA_CMD create -n $ENVIRONMENT_NAME python=3.9 -y

# Activate conda environment
activate_conda_env ${ENVIRONMENT_NAME}

# First install everything but dynet
pip install -r requirements.txt

# Method 1: from here https://github.com/clab/dynet/issues/1662#issuecomment-1582721356
pip install cython
pip install 'setuptools<57.0.0'
BACKEND=cuda pip install --verbose dynet --no-build-isolation
