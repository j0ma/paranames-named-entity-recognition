#!/usr/bin/env bash

#config_file="config/masakhaner/$(ls config/masakhaner/ | rg _cfg | fzf --tac)"
num_parallel_jobs=${1:-24}
n_seeds=${2:-1}
log_folder=${3:-./masakhane_log}

mkdir -p $log_folder

get_newline_separated_values () {
    local msg=$1
    echo "${msg}" | vipe | rg -v "^#"
}

gather_all_params () {
    languages=$(ls data/masakhaner | rg -v "(conll|pcm|luo|fix\.sh)" | vipe)
    seeds=$(get_newline_separated_values "# Enter seeds, one per line")
    lstm_hidden_sizes=$(get_newline_separated_values "# Enter LSTM hidden size dimensions, one per line")
    embedding_dimensions=$(get_newline_separated_values "# Enter word embedding dimensions, one per line")
    cfgfiles=$(ls config/masakhaner/ | rg _cfg | vipe | rg -v "^#")

    parallel echo ::: $seeds ::: $languages ::: $lstm_hidden_sizes ::: $embedding_dimensions ::: $cfgfiles | tr " " "\t" \
        | xsv sort -d"\t" -s 1,5 | xsv fmt -t"\t"

}


gather_all_params |\
while read experiment_spec
do
    export masakhaner_lang=$(echo $experiment_spec | cut -f2 -d' ')
    export tr_random_seed=$(echo $experiment_spec | cut -f1 -d' ')
    export tr_lstm_hidden_size=$(echo $experiment_spec | cut -f3 -d' ')
    export tr_word_embed_dim=$(echo $experiment_spec | cut -f4 -d' ')
    config_file=config/masakhaner/$(echo $experiment_spec | cut -f5 -d' ')

    echo "tr_random_seed=${tr_random_seed} tr_lstm_hidden_size=$tr_lstm_hidden_size tr_word_embed_dim=$tr_word_embed_dim ./full_experiment.sh $config_file $masakhaner_lang \"false\" "true" > \"$log_folder/$(basename $config_file)_seed${tr_random_seed}_lstm${tr_lstm_hidden_size}_emb${tr_word_embed_dim}.log\""
done | tee masakhaner_sweep_commands_run.txt | parallel -j "${num_parallel_jobs}" -I {} "{}"
