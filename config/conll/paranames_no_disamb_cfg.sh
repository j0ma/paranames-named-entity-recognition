#!/usr/bin/env bash

# Experiment creation
export ec_root_folder="experiments"
export ec_experiment_name="conll2003"
export ec_model_name="paranames_no_disambiguation_bsz16"
export ec_raw_data_folder="data/masakhaner/conll_2003_en"

# Preprocessing
export pp_ngram_size=3
export pp_ner_types="LOC,PER,ORG"

# File names contained in raw data folder
export pp_train_file="train.txt"
export pp_dev_file="dev.txt"
export pp_test_file="test.txt"
export pp_paranames_tsv_file="data/paranames_non_disambiguated/paranames_en.tsv"
export pp_should_disambiguate="false"
export pp_disambiguation_rules="{}"

# Train
export tr_mem_size=512
export tr_batch_size=16
export tr_num_epochs=200
export tr_use_softgaz_features="true"
