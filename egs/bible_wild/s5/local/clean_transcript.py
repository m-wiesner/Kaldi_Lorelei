#!/usr/bin/env python
from __future__ import print_function
import argparse
import sys
import unicodedata


# Keep Markings such as vowel signs, all letters, and decimal numbers 
VALID_CATEGORIES = ('Mc', 'Mn', 'Ll', 'Lm', 'Lo', 'Lt', 'Lu', 'Nd', 'Zs')


def _filter(s):
    return unicodedata.category(s) in VALID_CATEGORIES


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('text_orig')
    parser.add_argument('lexicon')
    parser.add_argument('--script', default='isLatin')
    args = parser.parse_args()

    words = set()
    with open(args.lexicon, 'r', encoding='utf-8') as f:
        for l in f:
            words.add(l.strip().split(None, 1)[0])

    with open(args.text_orig, 'r', encoding='utf-8') as f:
        for l in f:
            key, val = _read_entry(l, _filter)
            if key == None:
                continue;
            if len(val.split()) == 0:
                continue;
            print(key, end=' ')
            for w in val.split()[:-1]:
                if w in words:
                    print(w, end=' ')
                else:
                    print('<unk>', end=' ')  
            if val.split()[-1] in words:
                print(val.split()[-1])
            else:
                print('<unk>')


def _read_entry(l, filterfun):
    try:
        key, val = l.strip().split(None, 1)
        new_val = ''.join(
            [i for i in filter(filterfun, val.strip().replace('-', ' '))]
        ).lower()   
        return key, new_val
    except ValueError:
        return None, None  


if __name__ == "__main__":
    main() 
