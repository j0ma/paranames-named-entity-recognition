#!/usr/bin/env bash

# Experiment creation
export ec_root_folder="experiments"
export ec_experiment_name="baseline_vs_paranames_bsz16"
export ec_model_name="baseline_no_softgaz"
export ec_raw_data_folder="data/masakhaner/kin"

# Preprocessing
export pp_ngram_size=3
export pp_ner_types="LOC,PER,ORG,DATE"

# File names contained in raw data folder
export pp_train_file="train.txt"
export pp_dev_file="dev.txt"
export pp_test_file="test.txt"
export pp_kb_file="./data/en_kb"
export pp_links_file="./data/wiki_gazetteers_fixed/eng-kin_links"

# Train
export tr_mem_size=512
export tr_batch_size=16
export tr_num_epochs=200
export tr_use_softgaz_features="false"
