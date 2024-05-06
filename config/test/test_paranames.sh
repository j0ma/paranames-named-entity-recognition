#!/usr/bin/env bash

# Experiment creation
export ec_root_folder="experiments"
export ec_experiment_name="TEST_baseline_vs_paranames"
export ec_model_name="paranames_largebatch"
export ec_raw_data_folder="data/masakhaner/kin"

# Preprocessing
export pp_ngram_size=3
export pp_ner_types="LOC,PER,ORG,DATE"

# File names contained in raw data folder
export pp_train_file="train.txt"
export pp_dev_file="dev.txt"
export pp_test_file="test.txt"
#export pp_kb_file="./data/paranames/paranames_kin.kb"
#export pp_links_file="./data/paranames/paranames_kin.links"
export pp_paranames_tsv_file=./paranames/rw/paranames_rw.tsv
export pp_existing_data_folder=./experiments/turku/turku_finnish_ner_seed1_lstm128_emb100/train/fin_paranames_bsz16/supplemental_data

# Train
export tr_mem_size=5000
export tr_batch_size=160
export tr_num_epochs=2
export tr_use_softgaz_features="true"
