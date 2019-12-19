#!/usr/bin/env python
#-*- coding: utf-8 -*-
# Copyright 2019  Johns Hopkins University (Author: Matthew Wiesner)
# Apache 2.0

from __future__ import print_function
import argparse
import sys
import os


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('lexicon',
        help='lexicon to transform',
        type=str
    )
    parser.add_argument('transformed',
        help='transformed lexicon',
        type=str
    )
    args = parser.parse_args()

    with open(args.lexicon, 'r', encoding='utf-8') as f:
        with open(args.transformed, 'w', encoding='utf-8') as fo:
            for l in f:
                word, pron = l.strip().split('\t', 1)
                if word == '<hes>':
                    continue;
                new_word = word.lower().replace('_', ' ').replace('-', ' ').replace('/', '')
                new_pron = pron.replace('\t', ' ')
                print(u'{}\t{}'.format(new_word, new_pron), file=fo)


if __name__ == "__main__":
    main()

