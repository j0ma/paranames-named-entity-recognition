"""
Creates soft gazetteer features for an input file in conll format given a list of entity linking candidates for ngrams up to length 3.

Authors: 
    * Original author: Shruti Rijhwani
    * This version/fork: Jonne Sälevä
Contact: jonnesaleva@brandeis.edu

Please cite (original paper): 
Soft Gazetteers for Low-Resource Named Entity Recognition (ACL 2020)
https://www.aclweb.org/anthology/2020.acl-main.722
"""

import argparse
from collections import Counter
from pathlib import Path

import epitran
import numpy as np
from rich import print as pprint
from tqdm import tqdm

ALL = ["all"]


class SoftGazFeatureCreator(object):
    def __init__(
        self, kb_file, feat_types, candidate_file, epilang, normalize, ner_types
    ):
        if feat_types == ALL:
            self.feats = ["top1", "top30", "top3", "margin"]
        else:
            self.feats = feat_types

        if epilang:
            self.epi = epitran.Epitran(epilang)
        else:
            self.epi = None

        self.normalize = normalize

        type_codes = {ner_type: type_ix for type_ix, ner_type in enumerate(ner_types)}

        if "LOC" in type_codes:
            type_codes["GPE"] = type_codes["LOC"]

        pprint("Here are the types:")
        pprint(type_codes)

        self.num_types = len(type_codes)

        self.type_lookup = self.load_kb(kb_file, type_codes)
        self.ngram_candidates = self.load_candidates(candidate_file)

    def load_kb(self, kb_file, type_codes):
        type_lookup = {}
        with open(kb_file, "r", encoding="utf8") as f:
            for line in f:
                # spl = [wiki_id, names/aliases, ner_type]
                spl = line.strip().split(" ||| ")

                if spl[2] != "null":
                    # spl[0] = wiki_id; spl[2] = ner_type
                    type_lookup[spl[0]] = type_codes[spl[2]]

        return type_lookup

    def load_candidates(self, candidate_file):
        ngram_candidates = {}
        with open(candidate_file, "r", encoding="utf8") as f:
            for line in f:
                # spl = [span_string, wiki_id, ...]
                spl = line.strip().split(" ||| ")

                if len(spl) < 2:
                    continue
                ngram_candidates[spl[0]] = spl[1]

        return ngram_candidates

    def get_ngram_contexts(self, idx, sent, n):
        contexts = [0] * n

        for k in range(n):
            lower = idx + 1 - n + k
            upper = idx + 1 + k
            ngram_ctx_tokens = sent[lower:upper]
            ngram_ctx_string = " ".join(ngram_ctx_tokens)
            contexts[k] = ngram_ctx_string

        return contexts

    def create_features(self, conll_file):
        sents = []
        cur_sent = []

        # Read in the text from the input conll file into a list of sentences
        with open(conll_file, "r", encoding="utf8") as f:
            for line in f:
                if line == "\n":
                    sents.append(cur_sent)
                    cur_sent = []

                    continue
                spl = line.strip().split()
                cur_sent.append(spl[0])
            sents.append(cur_sent)

        inputfile_feats = []

        # Compute features for each sentence based on spans up to length 3
        already_printed_matches = set()

        for sent in tqdm(sents, desc="Constructing sentence features..."):
            sent_feats = []

            for i, word in enumerate(sent):
                feats = []

                for n in range(1, 4):
                    # Feature vectors for span length n for the current word
                    top1_scores = np.zeros(shape=(2, self.num_types))
                    top3_counts = np.zeros(shape=(3, self.num_types))
                    top3_scores = np.zeros(shape=(3, self.num_types))
                    top30_counts = np.zeros(shape=(self.num_types,))
                    margins = np.zeros(shape=(3,))

                    # Get all spans of length n that contain the current word
                    contexts = self.get_ngram_contexts(i, sent, n)

                    # Compute features for each context

                    for j, context_g in enumerate(contexts):
                        # Convert context to IPA if the candidates are in IPA

                        if self.epi:
                            context = self.epi.transliterate(context_g)
                        else:
                            context = context_g

                        if (
                            context not in self.ngram_candidates
                            or not context
                            or len(context.split()) != n
                        ):
                            continue
                        elif context not in already_printed_matches:
                            pprint(
                                f"Match found: {context} -> {self.ngram_candidates[context]}"
                            )
                            already_printed_matches.add(context)

                        # Get candidates for the current context
                        def safe_unpack(cand_str, default_weight=1.0):
                            """Safely unpack a candidate tuple with a default weight."""
                            tokens = cand_str.split(" | ")
                            try:
                                candidate, weight = tokens
                                weight = float(weight)
                            except ValueError:
                                candidate, weight = tokens[0], default_weight

                            return candidate, weight

                        candidates = self.ngram_candidates[context].split(" || ")
                        cands = [safe_unpack(cand) for cand in candidates]

                        if "top1" in self.feats:
                            top1 = cands[0]

                            if top1[0] in self.type_lookup:
                                if j == len(contexts) - 1:
                                    top1_scores[0][self.type_lookup[top1[0]]] += float(
                                        top1[1]
                                    )
                                else:
                                    top1_scores[1][self.type_lookup[top1[0]]] += float(
                                        top1[1]
                                    )

                        if len(cands) < 3:
                            continue

                        if "top3" in self.feats:
                            for k in range(3):
                                cand = cands[k]
                                top3_counts[k][self.type_lookup[cand[0]]] += 1
                                top3_scores[k][self.type_lookup[cand[0]]] += float(
                                    cand[1]
                                )

                        if "top30" in self.feats:
                            for cand in cands[:30]:
                                top30_counts[self.type_lookup[cand[0]]] += 1

                        if len(cands) < 4:
                            continue

                        if "margin" in self.feats:
                            for k in range(3):
                                margins[k] += float(cands[k][1]) - float(
                                    cands[k + 1][1]
                                )

                    # Normalize vectors after adding scores from all spans of length n

                    if self.normalize:
                        top1_scores = top1_scores / len(contexts)

                        for k in range(3):
                            top3_counts[k] = top3_counts[k] / len(contexts)
                            top3_scores[k] = top3_scores[k] / len(contexts)
                        top30_counts = top30_counts / (30 * len(contexts))
                        margins = margins / len(contexts)

                    # Concatenate all feature vectors for the current span length
                    feats.append(
                        np.hstack(
                            (
                                top1_scores.reshape(
                                    2 * self.num_types,
                                ),
                                top3_counts.reshape(
                                    3 * self.num_types,
                                ),
                                top3_scores.reshape(
                                    3 * self.num_types,
                                ),
                                top30_counts,
                                margins,
                            )
                        )
                    )

                # Concatenate vectors from all span lengths for the current word
                feats = np.hstack(tuple(feats))
                sent_feats.append(feats)

            # Append current sentence's features to the list of features for the input conll file
            inputfile_feats.append(np.array(sent_feats))

        # Return sentence-wise list of features

        return inputfile_feats


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--candidates",
        help="candidate file from exact match, WikiMention, PBEL or other candidate generation methods",
    )
    parser.add_argument("--kb", help="knowledge base file")
    parser.add_argument(
        "--normalize",
        action="store_true",
        help="boolean value for creating the features normalized or unnormalized (normalize recommended)",
    )
    parser.add_argument(
        "--feats",
        nargs="+",
        default=ALL,
        help="feature types: top1, top30, top3, margin",
    )
    parser.add_argument("--conll_file", help="conll file to process into features")
    parser.add_argument(
        "--epilang",
        default=None,
        help="If candidates are in IPA (e.g., from PBEL), convert input conll text to IPA using epitran",
    )
    parser.add_argument("--output_folder", help="output folder name")
    parser.add_argument(
        "--ner_types", help="comma-separated list of NER types.", default="LOC,PER,ORG"
    )
    args = parser.parse_args()

    parsed_ner_types = args.ner_types.split(",")

    feature_creator = SoftGazFeatureCreator(
        kb_file=args.kb,
        feat_types=args.feats,
        candidate_file=args.candidates,
        epilang=args.epilang,
        normalize=args.normalize,
        ner_types=parsed_ner_types,
    )

    inputfile_feats = feature_creator.create_features(conll_file=args.conll_file)
    are_all_feats_zero = all(s == 0.0 for s in [arr.sum() for arr in inputfile_feats])
    pprint(f"All features 0? {are_all_feats_zero}")
    pprint(Counter(a.sum() for a in inputfile_feats))
    conll_path = Path(args.conll_file)
    output_name = f"{conll_path.name}.softgazfeats"
    output_fname = Path(args.output_folder) / output_name

    # Save sentence-wise list of features as compressed numpy array; number of rows = number of sentences in the input file
    # Each row is a list of feature vectors (one for each word). The size of the list is the number of words in the sentence.
    np.savez_compressed(str(output_fname), feats=np.array(inputfile_feats))
