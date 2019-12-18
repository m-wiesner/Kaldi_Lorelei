#!/usr/bin/env python
#-*- coding: utf-8 -*-
# Copyright 2019  Johns Hopkins University (Author: Matthew Wiesner)
# Apache 2.0

from __future__ import print_function
import argparse
import sys
import os
import unicodedata
import re

VOWELS = [
    '6',
    'I',
    'I\\',
    '}',
    'Y',
    'E',
    '{',
    '@\\',
    'e',
    'M',
    '7',
    'O',
    '1',
    'V',
    'Q',
    '9',
    '3\\',
    '3',
    '&',
    'U',
    'A',
    'y',
    '8',
    'U\\',
    '2',
    'a',
    'u',
    'i',
    'o',
    '@',
    '@`',
]

MODIFIERS = [
    '~',
    '_~',
    ':',
]

VOWELS_REGEX = '(' + '|'.join([i.replace('\\', '\\\\') + '(' + '|'.join(MODIFIERS) + ')?' for i in sorted(VOWELS, key=lambda x: len(x), reverse=True)]) + ')'

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('lexicon')

    args = parser.parse_args()

    with open(args.lexicon, encoding='utf-8') as f_lexicon:
        lexicon = parse_lexicon(f_lexicon)

    for w in sorted(lexicon.keys()):
        for pron in lexicon[w]:
            print(w.lower(), end='\t')
            new_pron_list = []
            for p in pron.split():  
                if re.match(VOWELS_REGEX, p) is None:
                    new_pron_list.append(p)
                else:      
                    p_new = ' '.join(i[0] for i in re.findall(VOWELS_REGEX, p))
                    new_pron_list.append(p_new)
            new_pron = ' '.join(new_pron_list)
            new_pron = re.sub(r":", r"_:", new_pron) # Treat length as optional feature on which to split phonemes
            new_pron = re.sub(r"'", r'_j', new_pron) # ' --> _j depending on the XSAMPA representation
            new_pron = re.sub(r"gj", r'J\\', new_pron) # gj --> J\ (Turkish uses gj for some reason)
            new_pron = re.sub(r"Hi", r'H i', new_pron) # Hi --> H i (Haitina Diphthong with H which is not listed as a vowel in the
                                                        #           XSAMPA wikipedia entry)
            new_pron = re.sub(r"_hj", r"_h_j", new_pron) # _hj --> _h_j
            new_pron = re.sub(r"_cj", r"_c_j", new_pron) # _cj --> _c_j
            new_pron = re.sub(r'~', r'_~', new_pron) # ~ --> _~
            print(new_pron)

def parse_lexicon(f):
    # Figure out how many fields
    elements = {}
    pron_start_idx = 1
    for l in f:
        element = l.strip().split('\t')
        elements[element[0]] = element[1:]
        if len(element[1:]) < 2:
            pron_start_idx = 0

    lexicon = {}
    for word in elements:
        for pron in elements[word][pron_start_idx:]:
            pron = ' '.join(re.sub('[#."%]| _[0-9]', '', pron).split())
            if word not in lexicon:
                lexicon[word] = []
            lexicon[word].append(pron)
    return lexicon


if __name__ == "__main__":
    main()


