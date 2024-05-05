# ParaNames - NER experiments

### Prerequisites
- At least `prepx` will be needed (link)

### How to run things?
- That's what we're trying to figure out 😆

The main workhorse is `full_experiment.sh` which you run with

```
bash ./full_experiment.sh "${config_file_path}" "${language}" "${should_confirm}"
```

where
- `config_file_path` is a path to the configuration file for the experiment
- `language` is the relevant language code for the experimental data
- `should_confirm`: a boolean (`yes`/`no`) for interactively confirming commands.