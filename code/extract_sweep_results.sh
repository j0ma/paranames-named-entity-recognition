#!/usr/bin/env bash

set -euxo

export results_output_folder=scratch/hparam_sweep

langs=${1:-""}
entity_types=${2:-""}

analyze () {

    local exp_folder=$1
    local split=$2
    local languages=${3:-""}
    local entity_types=${4:-""}
    local out_folder=${5:-${results_output_folder}}

    mkdir -p $out_folder/{dev,test}

    langs_flag=$(test -n "${languages}" && echo "--languages ${languages}" || echo "")
    entity_types_flag=$(test -n "${entity_types}" && echo "--entity-types ${entity_types}" || echo "")

    python code/analyze_masakhaner.py \
        --split $split experiments/$exp_folder \
        $langs_flag \
        $entity_types_flag \
        | pee "head -n1" "rg ALL" \
        | xsv select -d"\t" Language,Features,F1 \
        | xsv fmt -t"\t" \
        > $out_folder/${split}/${exp_folder}_${split}_microf1.tsv
}

export -f analyze

parallel --bar --link \
    "analyze {1} {2} $langs $entity_types" \
    ::: $(ls experiments/ | vipe) \
    ::: "dev" "test"
