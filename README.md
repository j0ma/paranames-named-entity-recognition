# ParaNames - NER experiments

### Documentation
- [[full_experiment_sh_docs|full_recipes.sh]]

### How to run things?

#### Prerequisites
- At least `prepx` will be needed (link)

The main workhorse is `full_experiment.sh` which you run with

```
bash ./full_experiment.sh "${config_file_path}" "${language}" "${should_confirm}"
```

where
- `config_file_path` is a path to the configuration file for the experiment
- `language` is the relevant language code for the experimental data
- `should_confirm`: a boolean (`yes`/`no`) for interactively confirming commands.
	- if `yes`, an interactive `fzf` menu will be used to select tasks to run