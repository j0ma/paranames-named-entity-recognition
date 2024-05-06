#!/usr/bin/env bash

activate_conda_env () {
    source /home/$(whoami)/miniconda3/etc/profile.d/conda.sh
    conda activate ${1:-paranames-ner}
}
