
### Related scripts
- [`code/bilstm_crf_softgazetteers.py`](code/bilstm_crf_softgazetteers.py)
- [`code/create_softgaz_features.py`](code/create_softgaz_features.py)

### What it does

Main script for running the NER experiments. Mainly glues together other scripts and system tools.

### How to run

```bash
bash ./full_experiment.sh "${config_file_path}" "${language}" "${should_confirm}"
```

### How it works

The `main` function executes as the first thing inside the script. After handling arguments, the function sources the relevant config file and hacks together a command to confirm the commands that will be run. In case we actually want to confirm commands, this will be set to `fzf --sync --tac --multi`  but in case we do not, this will be set to `cat` which makes it a placeholder that passes the inputs through as-is.

```bash
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
```

The different commands to run are
- `check_deps`: checks dependencies
- `check_env`: checks that the environment has everything we need
- `create_experiment`: uses `prepx` to create a dedicated folder for the experiment
- `preprocess`: runs any preprocessing logic
- `train`: runs the actual LSTM-CFF training logic
- `evaluate`: runs `seqscore` for evaluation

#### `check_deps`

```bash
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
```

The logic here is simple. The command `which ${dep}` will look for the executable that `${dep}` points to. If found, it will return it as a nonempty string. If there is no executable to be found the command will return an empty string. The `sh`  command `test -z` will test if the string is empty, so `test -z $(which ${dep})` effectively tests whether a given dependency exists. We do this for each of `prepx`, `seqscore` and `jq` which we have hardcoded (🤮) into the function.

#### `check_env`

This function checks that all the relevant environment variables have been set.

```bash
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
```

It first checks for "mandatory variables" which must be explicitly specified by teh user.
Then, the function makes use of another helper function `fill_optionals`:

```bash
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
```

If a value is not present in the environment, it will be filled with a default value.

#### `preprocess`

This function performs all the necessary preprocessing that creates the soft gazetteer features based on ParaNames.
If the paths to the relevant files exist, the function will simply symlink them to the experiment folder. Otherwise, the function calls `data/get_ngrams.py`, `data/create_kb_and_links_paranames.py` and `python code/create_softgaz_features.py` with the relevant arguments.


```bash
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

r}
```

#### `train`

Really just a wrapped call to `code/bilstm_crf_softgazetteers.py` with proper arguments set based on values of the environment variables:

```bash
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
```

#### `evaluate`

Wrapped call around `seqscore score` with argument handling based on values of environment variables:

```bash
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
```