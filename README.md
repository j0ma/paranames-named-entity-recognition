# ParaNames - NER experiments

This repository contains the necessary data and code to run our NER experiments.

Before you start, do the following:

1. Get the following data files
	- MasakhaNER: `data/masakhaner/*/{train,dev,test}.txt`
	- Finnish: `data/turku-fin-ner/{train,dev,test}.txt`
	- Hindi:`data/hiner/collapsed/{train,dev,test}.json`
2. Put the ParaNames TSV files in a folder called `paranames` in the root of the repo
	- Tip: symlinks will work, too
3. Run `bash setup.sh` which will set up a Conda environment and attempts to install DyNet
	- NOTE: Installing [DyNet](https://github.com/clab/dynet) may require manual intervention

The main workhorse is `full_experiment.sh` which you run with

```
bash ./full_experiment.sh "${config_file_path}" "${language}" "${should_confirm}"
```

where
- `config_file_path` is a path to the configuration file for the experiment
- `language` is the relevant language code for the experimental data
- `should_confirm`: a boolean (`yes`/`no`) for interactively confirming commands.
	- if `yes`, an interactive `fzf` menu will be used to select tasks to run

## Dataset links
- African languages: [MasakhaNER](https://github.com/masakhane-io/masakhane-ner/tree/main)
- Finnish: [Turku NLP corpus](https://github.com/TurkuNLP/turku-ner-corpus)
- Hindi: [HiNER](https://github.com/cfiltnlp/HiNER)

## More documentation
- [`full_experiment.sh`](./docs/full_experiment_sh_docs.md)
