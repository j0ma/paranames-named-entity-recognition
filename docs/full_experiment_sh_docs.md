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
	- TODO: what?
- `train`: runs the actual LSTM-CFF training logic
	- TODO: what?
- `evaluate`: runs `seqscore` for evaluation
	- TODO: what?

##### `check_deps`

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