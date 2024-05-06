from collections import defaultdict
import csv

from rich import print as pprint
import click
import pudb
import json

DEFAULT_DISAMBIGUATION_RULES = {
    "LOC-ORG": "LOC",
    "LOC-ORG-PER": "ORG",
    "ORG-PER": "ORG",
    "LOC-PER": "PER",
}


def disambiguate(kb, rules):
    pprint("[disambiguate]", rules)
    disambiguated = defaultdict(list)
    for wiki_id, tuples in kb.items():
        other = [o for o, _ in tuples][0]
        types = [t for _, t in tuples]
        if len(types) > 1:
            conflicting_types = "-".join(sorted(types))
            new_type = rules[conflicting_types]
            disambiguated[wiki_id] = [(other, new_type)]
        else:
            disambiguated[wiki_id] = kb[wiki_id]

    return disambiguated


def load_paranames(
    kb_file, disambiguation_rules=DEFAULT_DISAMBIGUATION_RULES, should_disambiguate=True
):
    type_lookup_kb_rows = []
    type_lookup = defaultdict(list)
    other2id = {}

    with open(kb_file, encoding="utf-8") as kb_in:
        next(kb_in)
        dr = csv.DictReader(
            kb_in,
            fieldnames=["wikidata_id", "eng", "label", "language", "conll_type"],
            delimiter="\t",
        )
        for line in dr:
            wiki_id, other, ner_type = (
                line["wikidata_id"],
                line["label"],
                line["conll_type"],
            )
            type_lookup[wiki_id].append((other, ner_type))
            other2id[other] = wiki_id

    pprint(type_lookup)
    if should_disambiguate and len(disambiguation_rules):
        type_lookup = disambiguate(type_lookup, disambiguation_rules)

    for wiki_id, tuples in type_lookup.items():
        for (other, ner_type) in tuples:
            type_lookup_kb_rows.append(f"{wiki_id} ||| {other} ||| {ner_type}")

    return other2id, type_lookup_kb_rows


@click.command()
@click.option("--ngrams_file", type=click.Path(file_okay=True))
@click.option("--paranames_tsv", type=click.Path(file_okay=True))
@click.option("--kb_out", type=click.Path(file_okay=True))
@click.option("--links_out", type=click.Path(file_okay=True))
@click.option("--dont_disambiguate", is_flag=True)
@click.option("--disambiguation_rules")
def retrieve_candidates(
    ngrams_file,
    paranames_tsv,
    kb_out,
    links_out,
    dont_disambiguate,
    disambiguation_rules,
):
    """Retrieves candidate links"""
    pprint(ngrams_file, paranames_tsv, kb_out, links_out)
    disambiguation_rules = {"{}": {}}.get(
        disambiguation_rules, DEFAULT_DISAMBIGUATION_RULES
    )
    pprint(disambiguation_rules, type(disambiguation_rules))
    gaz, kb = load_paranames(
        paranames_tsv,
        disambiguation_rules=disambiguation_rules,
        should_disambiguate=bool(not dont_disambiguate),
    )

    links = []
    with open(ngrams_file, encoding="utf-8") as ngrams_in:
        for ngram in ngrams_in:
            ngram = ngram.strip()
            if ngram in gaz:
                links.append(f"{ngram} ||| {gaz[ngram]} | 1.0")

    print(f"Links: {len(links)}")

    with open(kb_out, encoding="utf-8", mode="w") as kbout:
        for row in kb:
            click.echo(row, file=kbout)

    with open(links_out, encoding="utf-8", mode="w") as links_out:
        for link in links:
            click.echo(link, file=links_out)


if __name__ == "__main__":
    retrieve_candidates()
