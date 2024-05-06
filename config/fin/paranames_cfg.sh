#!/usr/bin/env bash

# Experiment creation
export ec_root_folder="experiments"
export ec_experiment_name="turku_finnish_ner"
export ec_model_name="fin_paranames_bsz16"
export ec_raw_data_folder="data/turku-fin-ner/"

# Preprocessing
export pp_ngram_size=3
export pp_ner_types="DATE,EVENT,LOC,ORG,PER,PRO"

# File names contained in raw data folder
export pp_train_file="train.txt"
export pp_dev_file="dev.txt"
export pp_test_file="test.txt"
export pp_paranames_tsv_file="./paranames/fi/paranames_fi.tsv"
export pp_should_disambiguate="true"
export pp_disambiguation_rules="default"
export pp_existing_data_folder=./data/turku-fin-ner/supplemental_data

# Train
export tr_mem_size=512
export tr_batch_size=16
export tr_num_epochs=50
export tr_use_softgaz_features="true"
