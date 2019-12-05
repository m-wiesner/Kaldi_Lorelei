#!/usr/bin/env python
#-*- coding: utf-8 -*-
# Copyright 2019  Johns Hopkins University (Author: Matthew Wiesner)
# Apache 2.0

from __future__ import print_function
import argparse
import sys
import os
import subprocess
import json


data = '/export/corpora5/datasets-CMU_Wilderness'
#*/asr_files/transcription_nopunc.txt'

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('book_chapters',
        help='',
        type=str
    )
    parser.add_argument('langs')
    parser.add_argument('book_chapter_lang_counts')
    parser.add_argument('--count-thresh', type=int, help='min count for each language', default=50)
    parser.add_argument('--book-chapter-json', default=None)

    args = parser.parse_args()
    
    with open(args.book_chapters) as f:
        book_chapters = [l.strip() for l in f.readlines()]
    
    with open(args.langs) as f:
        langs = [l.strip() for l in f.readlines()]
   
    if args.book_chapter_json is not None:
        book_chapter_dict = json.load(open(args.book_chapter_json)) 
    else:
        book_chapter_dict = {}
        for bc in book_chapters:
            counts = []
            lang_order = []
            for lang in langs:
                cmd = 'grep {} {}/{}/asr_files/transcription_nopunc.txt | wc -l'.format(bc, data, lang)
                output = subprocess.check_output(cmd, shell=True)
                counts.append(int(output))
                lang_order.append(lang)
            book_chapter_dict[bc] = [counts, langs]
    
    book_chapter_dict_ = {}
    for bc in book_chapter_dict:
        book, chapter = bc.split('___', 1)
        if book not in book_chapter_dict_:
            book_chapter_dict_[book] = {}
        book_chapter_dict_[book][int(chapter.split('_')[0])] = book_chapter_dict[bc][0]
  
    book_chapter_dict_coverage = {} 
    for b in book_chapter_dict_:
        book_chapter_dict_coverage[b] = {}
        for c in book_chapter_dict_[b]:
            book_chapter_dict_coverage[b][c] = sum(i > args.count_thresh for i in book_chapter_dict_[b][c]) 
   
    for b in sorted(book_chapter_dict_coverage):
        best_book = sorted(book_chapter_dict_coverage[b].items(), reverse=True, key=lambda x: x[1])[0]
        print(b, best_book) 
    
    #with open(args.book_chapter_lang_counts, 'w') as f:
    #    json.dump(book_chapter_dict_coverage, f, indent=4, separators=(',', ': '))

    print()

if __name__ == "__main__":
    main()

