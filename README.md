# ParaNames - NER experiments

### Documentation
- [`full_experiment.sh`](./docs/full_experiment_sh_docs.md)

### How to run things?

#### Prerequisites
- At least `prepx` will be needed (link)
- What data needs to be prepared?
- What about the configs?

#### Run the experiment

The main workhorse is `full_experiment.sh` which you run with

```
bash ./full_experiment.sh "${config_file_path}" "${language}" "${should_confirm}"
```

where
- `config_file_path` is a path to the configuration file for the experiment
- `language` is the relevant language code for the experimental data
- `should_confirm`: a boolean (`yes`/`no`) for interactively confirming commands.
	- if `yes`, an interactive `fzf` menu will be used to select tasks to run
