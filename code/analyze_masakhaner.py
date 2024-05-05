import csv
import sys
from pathlib import Path
from collections import defaultdict

import pandas as pd
import click

dev = "dev"
test = "test"
ignore = "ignore"
softgaz_feat_types = ["no_softgaz", "paranames", "paranames_no_disambiguation"]
_entity_types = ["DATE", "LOC", "ORG", "PER"]
_languages = ["amh", "hau", "ibo", "lug", "wol", "yor", "swa", "kin"]
seqscore_columns = [
    "Type",
    "Precision",
    "Recall",
    "F1",
    "Reference",
    "Predicted",
    "Correct",
]


def remove_prefix(s, prefix):
    return s[len(prefix) :] if s.startswith(prefix) else s


def remove_suffix(s, suffix):
    return s[: -len(suffix)] if s.endswith(suffix) else s


def convert_to_number(x):
    try:
        return int(x)
    except ValueError:
        try:
            return float(x)
        except ValueError:
            return x


def process_results(score_path, lang, feat_type, skip_header=True):

    with open(score_path, "r", encoding="utf-8") as fin:
        reader = csv.DictReader(f=fin, fieldnames=seqscore_columns, delimiter="\t")
        out = []

        # Skip the header row

        if skip_header:
            next(reader)

        for row in reader:
            d = {key: convert_to_number(val) for key, val in row.items()}
            d["Language"] = lang
            d["Features"] = feat_type
            out.append(d)

        return pd.DataFrame.from_records(out)


@click.command()
@click.argument(
    "experiment_folder", type=click.Path(exists=True, file_okay=False, dir_okay=True)
)
@click.option("--split", type=click.Choice(["dev", "test"]), default=test)
@click.option("--if-not-found", type=click.Choice(["ignore", "error"]), default=ignore)
@click.option("--languages", default="", help="Comma-separated list of languages.")
@click.option("--entity-types", default="", help="Comma-separated list of entity types.")
def main(experiment_folder, split, if_not_found, languages, entity_types):

    if not languages:
        languages = _languages
    else:
        languages = languages.split(",")

    if not entity_types:
        entity_types = _entity_types
    else:
        entity_types = entity_types.split(",")

    results = []

    for lang in languages:
        paths = Path(f"{experiment_folder}/eval/").glob(f"eval_{lang}_*_bsz16")

        for eval_path in paths:
            feat_type = remove_prefix(eval_path.name, f"eval_{lang}_")
            feat_type = remove_suffix(feat_type, "_bsz16")

            score_path = eval_path / f"{split}-output" / f"score_{split}.tsv"

            if not score_path.exists() and if_not_found == ignore:
                continue
            results.append(process_results(score_path, lang, feat_type))

    results_df = pd.concat(results).round(2)
    results_df["Type"] = pd.Categorical(
        results_df["Type"],
        categories=["ALL", *entity_types],
        ordered=True,
    )
    results_df.set_index(["Language", "Type", "Features"], inplace=True)
    results_df.sort_index(inplace=True)
    results_df.to_csv(sys.stdout, sep="\t")


if __name__ == "__main__":
    main()
