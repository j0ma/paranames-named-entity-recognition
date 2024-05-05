#!/usr/bin/env bash

# Experiment creation
export ec_root_folder="experiments"
export ec_experiment_name="kaznerd_kazakh_ner"
export ec_model_name="kaz_paranames_no_disamb_bsz16"
export ec_raw_data_folder="data/kaznerd/"

# Preprocessing
export pp_ngram_size=3
export pp_ner_types="ADAGE,ART,CARDINAL,CONTACT,DATE,DISEASE,EVENT,FACILITY,GPE,LANGUAGE,LAW,LOCATION,MISCELLANEOUS,MONEY,NON_HUMAN,NORP,ORDINAL,ORGANISATION,PERCENTAGE,PERSON,POSITION,PRODUCT,PROJECT,QUANTITY,TIME"

# File names contained in raw data folder
export pp_train_file="IOB2_train.txt"
export pp_dev_file="IOB2_valid.txt"
export pp_test_file="IOB2_test.txt"
export pp_paranames_tsv_file="./data/kaznerd/paranames_kk_longformtypes.tsv"
export pp_should_disambiguate="false"
export pp_disambiguation_rules="{}"
#export pp_existing_data_folder=

# Train
export tr_mem_size=6000
export tr_batch_size=16
export tr_num_epochs=50
export tr_use_softgaz_features="true"
