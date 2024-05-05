#!/usr/bin/env bash

set -euo pipefail

# Experiment creation
export ec_root_folder="experiments"
export ec_experiment_name="hiner_hindi_ner"
export ec_model_name="hin_paranames_no_autoencoder_bsz16"
export ec_raw_data_folder="data/hiner/collapsed/"

# Preprocessing
export pp_ngram_size=3
export pp_ner_types="LOG,ORG,PER"

# File names contained in raw data folder
export pp_train_file="train.conll"
export pp_dev_file="validation.conll"
export pp_test_file="test.conll"
export pp_paranames_tsv_file="./paranames/hi/paranames_hi.tsv"

# Train
export tr_mem_size=512
export tr_batch_size=16
export tr_num_epochs=50
export tr_use_softgaz_features="true"
export tr_use_autoencoder_loss="false"
export tr_use_lstm_softgaz_features="true"
export tr_use_crf_softgaz_features="true"
export pp_existing_data_folder=./data/hiner/collapsed/supplemental_data
