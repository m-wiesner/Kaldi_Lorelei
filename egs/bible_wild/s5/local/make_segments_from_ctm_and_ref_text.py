#!/usr/bin/env python
#-*- coding: utf-8 -*-
# Copyright 2019  Johns Hopkins University (Author: Matthew Wiesner)
# Apache 2.0

from __future__ import print_function
import argparse
import sys
import os


def _read_ctm_line(l):
    try:
        recoid, _, start, dur, word= l.strip().split()
    except ValueError:
        recoid, _, start, dur, word, _ = l.strip().split()
    return recoid, (float(start), float(dur), word)


def _read_text_line(l):
    uttid, text = l.strip().split(None, 1)
    recoid, verse_start, verse_end = uttid.rsplit('_', 2)
    return recoid, (
        uttid,
        text.split()
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('text',
        help='',
        type=str
    )
    parser.add_argument('ctm')
    parser.add_argument('segments')
    args = parser.parse_args()

    # Read in CTM
    recoid2element_list = {}
    print("Reading", args.ctm, "...")
    with open(args.ctm) as f_ctm:
        for l in f_ctm:
            recoid, el = _read_ctm_line(l) # el = (start, duration, word)
            if recoid not in recoid2element_list:
                recoid2element_list[recoid] = []
            recoid2element_list[recoid].append(el)
   
    # Sort CTM by time 
    for recoid in recoid2element_list:
        recoid2element_list[recoid] = sorted(recoid2element_list[recoid], key=lambda x: x[0])  

    # Read Text 
    recoid2verses = {}
    print("Reading", args.text, "...")
    with open(args.text) as f_text:
        for l in f_text:
            recoid, verses = _read_text_line(l)
            if recoid not in recoid2verses:
                recoid2verses[recoid] = []
            recoid2verses[recoid].append(verses)
    
    # Sort Text by verse number 
    for recoid in recoid2verses:
        recoid2verses[recoid] = sorted(recoid2verses[recoid], key=lambda x: x[0])
   
    segments_dict = {}
    print("Aligning", args.ctm, "to", args.text, "...") 
    for recoid, ctm in sorted(recoid2element_list.items(), key=lambda x: x[0]):
        segments = recoid2verses[recoid]
        word = ''
        ctm_idx = 0
        seg_start = 0.0
        for seg in segments:
            uttid, text = seg
            for w in text:
                while(word != w and ctm_idx < len(ctm)):
                    start, dur, word = ctm[ctm_idx]
                    ctm_idx += 1
            end = float(start) + float(dur) 
            segments_dict[uttid] = '{} {} {:.2f} {:.2f}'.format(
                uttid, recoid, seg_start, end,
            )
            seg_start = end
    
    # Dump the segments to a file
    print("Dumping segments to", args.segments)
    with open(args.segments, 'w') as f_segments:
        for uttid, seg in sorted(segments_dict.items(), key=lambda x: x[0]):
            print(seg, file=f_segments)

    
if __name__ == "__main__":
    main()

