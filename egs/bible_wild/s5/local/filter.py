#!/usr/bin/env python
# -*- coding: utf-8 -*-

from __future__ import print_function
import argparse
import unicodedata


def parse_input():
    parser = argparse.ArgumentParser()
    parser.add_argument("counts", help="File of raw ngram counts")
    parser.add_argument("cleaned_counts", help="File of ngram counts "
                        "obtained by removing all ngrams with characters "
                        "that are not in the Tigrinya character set")
    return parser.parse_args()


# Keep Markings such as vowel signs, all letters. Numbers are removed since we
# have no pronunciations for them.
VALID_CATEGORIES = ('Mc', 'Mn', 'Ll', 'Lm', 'Lo', 'Lt', 'Lu', 'Zs')

def _filter(s):
    for c in s:
        if unicodedata.category(c) not in VALID_CATEGORIES:
            return False
    return True


def main():
    args = parse_input()
  
    with open(args.cleaned_counts, "w", encoding="utf-8") as fo:
        with open(args.counts, "r", encoding="utf-8") as fi:
            line_no = 0 
            for l in fi:
                print("\rLine ", line_no, end="") 
                line_no += 1
                try:
                    ngram, count = l.strip().split('\t')
                except ValueError:
                    ngram = l.strip()
                    count = '1'
                if _filter(ngram):
                    print(u"{}\t{}".format(ngram, count), file=fo)
   

if __name__ == "__main__":
    main()
    print()
