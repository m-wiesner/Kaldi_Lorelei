#!/usr/bin/env python
from __future__ import print_function
import sys
import argparse
import os
import string
from functools import partial
import LangFilters as lf


def parse_input():
    parser = argparse.ArgumentParser()
    parser.add_argument("keys", help="File with paths to files to process")
    parser.add_argument("text", help="Kaldi format text file output")
    parser.add_argument('--script', default='isLatin')
    return parser.parse_args()

def _filter(s, script=None):
    if script is not None:
        return s.isalnum() or s.isspace() or _isJoin(s)
    else:
        return s.isalnum() or s.isspace() or _isJoin(s) or script(s)

def _isJoin(s):
    if len(s) == 0:
        return False

    for c in s:
        if ord(c) not in range(8203, 8206):
            return False 
    return True

def main():
    args = parse_input()
    filterfun = partial(_filter, script=getattr(lf, args.script))
    odir = os.path.dirname(args.text)
    if not os.path.exists(odir) and odir != "":
        os.makedirs(odir)  

    files = []
    with open(args.keys, "r") as f:
        for l in f:
            files.append(l.strip())

    num_files = len(files)
    print("Number of Files: ", num_files)
    f_num = 1
    with open(args.text, "w", encoding="utf-8") as fo:
        for f in files:
            print("\rFile ", f_num, " of ", num_files, end="")
            text_id = os.path.basename(f).strip(".txt")
            with open(f, "r", encoding="utf-8") as fi:
                utt_num = 0
                for l in fi:
                    l_new = ''.join(
                        [i for i in filter(filterfun, l.strip().replace('-', ' '))]
                    ).lower()
                    #filter(_filter, l.strip().replace("-", " "))).lower()
                    if l_new.strip() != "":
                        print(u"{}_{:03} {}".format(text_id, utt_num, l_new), file=fo)
                        utt_num += 1
            f_num += 1
    print()

if __name__ == "__main__":
    main()

