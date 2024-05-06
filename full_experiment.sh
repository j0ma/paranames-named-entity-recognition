#!/usr/bin/env bash

# Complete experiment sequence for soft-gazetteers

set -euo pipefail

# Constants
config_file=$1
language=${2:-""}
should_confirm=${3:-"true"}
append_meta=${4:-"false"}

cuda_visible=${CUDA_VISIBLE_DEVICES:-""}

check_these_vars=(
    "ec_root_folder"
    "ec_experiment_name"
    "ec_model_name"
    "ec_raw_data_folder"
    "pp_ngram_size"
    "pp_train_file"
    "pp_dev_file"
    "pp_test_file"
    "pp_ner_types"
    "tr_mem_size"
    "tr_batch_size"
    "tr_num_epochs"
    "tr_use_softgaz_features"
)

source code/conda_stuff.sh

# Step 0: Dependencies
check_deps() {
    echo "❗  Checking dependencies..."
    external_dependencies=(prepx seqscore jq)
    for dep in "${external_dependencies[@]}"; do
        test -z "$(which $dep)" &&
            echo "Missing dependency: ${dep}" &&
            exit 1
    done
    echo "✅  Dependencies seem OK"
}

fill_optionals() {
    export pp_kb_file=${pp_kb_file:-""}
    export pp_links_file=${pp_links_file:-""}
    export pp_paranames_tsv_file=${pp_paranames_tsv_file:-""}
    export pp_disambiguation_rules=${pp_disambiguation_rules:-{}}
    export pp_should_disambiguate=${pp_should_disambiguate:-"true"}
    export pp_existing_data_folder=${pp_existing_data_folder:-""}
    export pp_ln_or_cp_cmd=${pp_ln_or_cp_cmd:-"ln"}
    export tr_use_lstm_softgaz_features=${tr_use_lstm_softgaz_features:-"true"}
    export tr_use_crf_softgaz_features=${tr_use_crf_softgaz_features:-"true"}
    export tr_use_autoencoder_loss=${tr_use_autoencoder_loss:-"true"}
    export tr_word_embed_dim=${tr_word_embed_dim:-100}     # default value from args.py
    export tr_lstm_hidden_size=${tr_lstm_hidden_size:-200} # default value from args.py
    export tr_random_seed=${tr_random_seed:-1}
}

check_env() {
    echo "❗ Checking environment..."

    # First check mandatory variables
    for var in "${check_these_vars[@]}"; do
        eval "test -z \$$var" &&
            echo "Missing variable: $var" &&
            missing="true" || missing="false"
    done
    test "$missing" = "true" && exit 1

    # Then check and fill optionals
    fill_optionals

    # Append seed to experiment name if necessary
    if [ "${append_meta}" = "true" ]; then
        export ec_experiment_name="${ec_experiment_name}_seed${tr_random_seed}_lstm${tr_lstm_hidden_size}_emb${tr_word_embed_dim}"
    fi

    echo "✅  Environment seems OK"
}

create_experiment() {
    echo "❗ Creating experiment..."

    prepx create \
        --with-tensorboard --with-supplemental-data \
        --root-folder="${ec_root_folder}" \
        --experiment-name="${ec_experiment_name}" \
        --train-name="${ec_model_name}" \
        --raw-data-folder="${ec_raw_data_folder}"

    echo "✅  Done!"
}

preprocess() {
    echo "❗ Preprocessing..."

    data_folder="${ec_root_folder}/${ec_experiment_name}/train/${ec_model_name}/raw_data"
    supplemental_data_folder="${ec_root_folder}/${ec_experiment_name}/train/${ec_model_name}/supplemental_data"

    export pp_ngrams_output_file="${supplemental_data_folder}/ngrams.txt"
    export pp_kb_output_file="${supplemental_data_folder}/kb.txt"
    export pp_links_output_file="${supplemental_data_folder}/links.txt"

    # If paths to files provided, just link
    if [ -n "${pp_existing_data_folder}" ]; then
        printf "\n\n%s\n\n" "🤗 Existing data folder found: ${pp_existing_data_folder}"
        printf "\n\n%s\n\n" "Using that instead of preprocessing again..."

        sleep 3
        ln_or_cp_cmd=$(
            test "${pp_ln_or_cp_cmd}" = "ln" \
            && echo "ln -s" || echo "cp"
        )
        for txt_fname in "ngrams" "kb" "links"
        do
            ${ln_or_cp_cmd} \
                "$(realpath ${pp_existing_data_folder}/${txt_fname}.txt)" \
                "${supplemental_data_folder}/${txt_fname}.txt"
        done
        for split in "train" "dev" "test"
        do
            case $split in
                "train")
                    split_fname="$(basename ${pp_train_file})" ;;
                "dev"|"valid"|"validation")
                    split_fname="$(basename ${pp_dev_file})" ;;
                "test")
                    split_fname="$(basename ${pp_test_file})" ;;
            esac
            ${ln_or_cp_cmd} \
                "$(realpath ${pp_existing_data_folder}/${split_fname}.softgazfeats.npz)" \
                "${supplemental_data_folder}/${split_fname}.softgazfeats.npz"
        done

    else
        if [ -n "${pp_paranames_tsv_file}" ]; then

            printf "\n\n%s\n\n" \
                "🤔 Retrieving links based on ParaNames file: $(basename ${pp_paranames_tsv_file})" &&
                sleep 3

            pp_kb_file=$pp_kb_output_file
            pp_links_file=$pp_links_output_file

            python data/get_ngrams.py \
                --n "${pp_ngram_size}" \
                --filenames \
                ${data_folder}/${pp_train_file} \
                ${data_folder}/${pp_dev_file} \
                ${data_folder}/${pp_test_file} \
                --output "${pp_ngrams_output_file}"

            disamb_flag=$(
                test "${pp_should_disambiguate}" = "false" &&
                    echo "--dont_disambiguate" ||
                    echo "--disambiguation_rules ${pp_disambiguation_rules}"
            )

            python data/create_kb_and_links_paranames.py \
                --ngrams_file "${pp_ngrams_output_file}" \
                --paranames_tsv "${pp_paranames_tsv_file}" \
                --kb_out "${pp_kb_file}" \
                --links_out "${pp_links_file}" ${disamb_flag}
        fi

        # Check that we have a KB and links file
        for varname in "pp_kb_file" "pp_links_file"; do
            test -z "$(echo $varname)" && echo "UNDEFINED VARIABLE $varname" && exit 1
        done

        cp -v $pp_kb_file $pp_kb_output_file || echo
        cp -v $pp_links_file $pp_links_output_file || echo

        for split_file in \
            "${data_folder}/${pp_train_file}" \
            "${data_folder}/${pp_dev_file}" \
            "${data_folder}/${pp_test_file}"; do
            python code/create_softgaz_features.py \
                --candidates "${pp_links_file}" \
                --kb "${pp_kb_file}" \
                --conll_file "${split_file}" \
                --normalize --feats all \
                --output_folder "${supplemental_data_folder}" \
                --ner_types "${pp_ner_types}"
        done
    fi
    echo "✅ Done!"

}

train() {
    echo "❗ Starting training..."

    data_folder="${ec_root_folder}/${ec_experiment_name}/train/${ec_model_name}/raw_data"
    supplemental_data_folder="${ec_root_folder}/${ec_experiment_name}/train/${ec_model_name}/supplemental_data"
    train_log_file="${ec_root_folder}/${ec_experiment_name}/train/${ec_model_name}/train.log"

    flag=""
    if [ "${tr_use_softgaz_features}" = "true" ]; then
        test "${tr_use_crf_softgaz_features}" = "true" &&
            flag="${flag} --crf_feats"
        test "${tr_use_lstm_softgaz_features}" = "true" &&
            flag="${flag} --lstm_feats"
        test "${tr_use_autoencoder_loss}" = "true" &&
            flag="${flag} --autoencoder"
    fi
    use_softgaz_features_flag="${flag}"

    batching_flag=$(
        test "${tr_batch_size}" = "auto" &&
            echo "--dynet-autobatching 1" ||
            echo "--batch_size ${tr_batch_size} --dynet-autobatching 0"
    )

    gpu_flag=$(
        test -n "${cuda_visible}" &&
            echo "--dynet-gpu" ||
            echo ""
    )

    eval_folder="${ec_root_folder}/${ec_experiment_name}/train/${ec_model_name}/eval/"
    checkpoint_folder="${ec_root_folder}/${ec_experiment_name}/train/${ec_model_name}/checkpoints"

    python code/bilstm_crf_softgazetteers.py \
        --embed "${tr_word_embed_dim}" \
        --word_hidden_size "${tr_lstm_hidden_size}" \
        --train "${data_folder}/${pp_train_file}" \
        --dev "${data_folder}/${pp_dev_file}" \
        --test "${data_folder}/${pp_test_file}" \
        --train_feats "${supplemental_data_folder}/${pp_train_file}.softgazfeats.npz" \
        --dev_feats "${supplemental_data_folder}/${pp_dev_file}.softgazfeats.npz" \
        --test_feats "${supplemental_data_folder}/${pp_test_file}.softgazfeats.npz" \
        ${use_softgaz_features_flag} \
        --output_folder "${eval_folder}" --output_name "${ec_model_name}" \
        --models_folder "${checkpoint_folder}" --num_epochs "${tr_num_epochs}" \
        --dynet-mem "${tr_mem_size}" ${batching_flag} ${gpu_flag} |
        tee -a "${train_log_file}"

    echo "✅ Done training..."
    echo "❗ Moving outputs and checkpoints to experiment folder..."
    echo "✅ Done!"
}

evaluate() {
    local split=$1
    echo "❗ [${split}] Evaluating..."

    eval_folder=${ec_root_folder}/${ec_experiment_name}/train/${ec_model_name}/eval/
    raw_output_file=${eval_folder}/${split//dev/dev.temp}.${ec_model_name}

    # create dedicated sub-folder for split
    split_eval_folder=${eval_folder}/${split}-output
    mkdir -p "${split_eval_folder}"
    mv "${raw_output_file}" "${split_eval_folder}/" || echo
    raw_output_file=${split_eval_folder}/$(basename "${raw_output_file}")

    # separate out columns
    tokens="${split_eval_folder}/tokens"
    hyps="${split_eval_folder}/hypotheses"
    refs="${split_eval_folder}/references"
    cut -f1 -d' ' "${raw_output_file}" >"${tokens}"
    cut -f2 -d' ' "${raw_output_file}" >"${refs}"
    cut -f3 -d' ' "${raw_output_file}" >"${hyps}"

    tokens_hypotheses="${split_eval_folder}/hypotheses_with_tokens"
    tokens_references="${split_eval_folder}/references_with_tokens"
    paste "${tokens}" "${hyps}" >"${tokens_hypotheses}"
    paste "${tokens}" "${refs}" >"${tokens_references}"

    seqscore score \
        --score-format pretty \
        --repair-method conlleval \
        --labels BIO \
        --reference "${tokens_references}" \
        "${tokens_hypotheses}" |
        tee ${split_eval_folder}/score_${split}.txt

    seqscore score \
        --score-format delim \
        --repair-method conlleval \
        --labels BIO \
        --reference "${tokens_references}" \
        "${tokens_hypotheses}" |
        tee ${split_eval_folder}/score_${split}.tsv

    echo "✅ Done!"

}

main() {
    local config=$1
    local language=${2:-""}
    local should_confirm_commands=${3:-"true"}

    [ -z "${language}" ] &&
        source "${config}" ||
        source "${config}" "${language}"

    confirm_commands_flag=$(
        test "${should_confirm_commands}" = "false" &&
            echo "cat" ||
            echo "fzf --sync --tac --multi"
    )

    echo check_deps check_env create_experiment preprocess train evaluate |
        tr " " "\n" |
        ${confirm_commands_flag} |
        while read command; do
            echo $command
            if [ "$command" = "evaluate" ]; then
                for split in "dev" "test"; do evaluate $split; done
            else
                $command
            fi
        done
}

main "${config_file}" "${language}" "${should_confirm}"
