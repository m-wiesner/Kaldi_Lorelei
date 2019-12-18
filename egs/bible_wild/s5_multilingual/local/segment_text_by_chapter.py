##!/usr/bin/env python
#-*- coding: utf-8 -*-
# Copyright 2019  Johns Hopkins University (Author: Matthew Wiesner)
# Apache 2.0

from __future__ import print_function
import argparse
import sys
import os
import re
import glob
import unicodedata


# Keep Markings such as vowel signs, all letters, and decimal numbers 
VALID_CATEGORIES = ('Mc', 'Mn', 'Ll', 'Lm', 'Lo', 'Lt', 'Lu', 'Nd', 'Zs')


def _filter(s):
    return unicodedata.category(s) in VALID_CATEGORIES


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('dir',
        help='',
        type=str
    )
    parser.add_argument('--chapter-segs', action='store_true')

    args = parser.parse_args()
    
    regex = re.compile(r'\s\s+[0-9]\s[^\s]+\s+[0-9]|(?<!^)\s\s+(?P<verse>[0-9]+(?:\s\s+-\s\s+[0-9]+)?)', re.UNICODE)
    files = glob.glob('{}/*.txt'.format(args.dir))
    for fname in sorted(files):
        chapter_id = os.path.splitext(os.path.basename(fname))[0]
        with open(fname, encoding='utf-8') as f:
            lines = f.readlines()
        verse = '00000_00000'
        for l in lines:
            verses = re.split(regex, l)
            for v in verses:
                if v is None:
                    if verse == '00000_00000':
                        if args.chapter_segs:
                            print(u'{} <unk>'.format(chapter_id, verse), end=' ')
                        else:
                            print(u'{}_{} <unk>'.format(chapter_id, verse))
                        continue;
                if v.strip('- ') != '':
                    v_name = '_'.join(v.replace('-', ' ').split())
                    verse_list = []
                    if re.match(r'^[0-9]+_[0-9]+$|^[0-9]+$', v_name):
                        vname_verses = v_name.split('_', 1)
                        if len(vname_verses) == 1:
                            verse = '{:05d}_{:05d}'.format(int(vname_verses[0]), int(vname_verses[0]))
                        else:
                            verse = '{:05d}_{:05d}'.format(int(vname_verses[0]), int(vname_verses[1]))
                    else:
                        if verse == '00000_00000':
                            if args.chapter_segs:
                                print(u'{} <unk>'.format(chapter_id, verse), end=' ')
                            else:
                                print(u'{}_{} <unk>'.format(chapter_id, verse))
                        else:
                            v_new = ''.join(
                                [i for i in filter(_filter, v.strip().replace('-', ' '))]
                            ).lower()
                            if args.chapter_segs:
                                print(v_new, end=' ')
                            else:
                                print(u'{}_{} {}'.format(chapter_id, verse, v_new))
            if args.chapter_segs:
                print() 

if __name__ == "__main__":
    main()

