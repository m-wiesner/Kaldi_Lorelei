#!/usr/bin/env python
# -*- coding: utf-8 -*-

from __future__ import print_function
import argparse
import LangFilters as lf


def parse_input():
    parser = argparse.ArgumentParser()
    parser.add_argument("counts", help="File of raw ngram counts")
    parser.add_argument("filterfun", help="Lorelei LangID")
    parser.add_argument("cleaned_counts", help="File of ngram counts "
                        "obtained by removing all ngrams with characters "
                        "that are not in the Tigrinya character set")
    return parser.parse_args()

def main():
    args = parse_input()
    filterfun = getattr(lf, args.filterfun)
  
    with open(args.cleaned_counts, "w", encoding="utf-8") as fo:
        with open(args.counts, "r", encoding="utf-8") as fi:
            line_no = 0 
            for l in fi:
                print("\rLine ", line_no, end="") 
                line_no += 1
                ngram, count = l.strip().split('\t')
                if filterfun(ngram):
                    print(u"{}\t{}".format(ngram, count), file=fo)
   

if __name__ == "__main__":
    main()
    print()
