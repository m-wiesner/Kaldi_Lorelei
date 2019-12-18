#!/bin/bash

# Copyright 2019  Matthew Wiesner
# Apache 2.0


# This script takes the full chapter transcripts and audio and breaks them into
# verses. The verses are mostly consistent across languages, though sometimes a
# single verse gets mapped to a sequence of verses or the other way around. The
# way we go about doing this is by first training a monolingual ASR system,
# using for instance, a graphemic lexicon and the segments provided by 
# CMU Wilderness. We then use this ASR (typically chain/tdnnf) to force align
# entire chapters. These tend to be long, but not too long for must of them to
# successfully align with a good enough ASR and large beam width. A phone-level
# ctm file is then used to extract the correct word sequence boundaries.
# This script specifically handles the verse and ctm alignment part.

cmd=run.pl
nj=50
online_ivector_dir=
scale_opts='--transition-scale=1.0 --self-loop-scale=1.0'
stage=0

. ./utils/parse_options.sh

if [ $# -ne 6 ]; then
  echo "Usage: ./local/align_by_verse_nnet3.sh <raw_data> <whole_recording_data> <lang> <src> <segmented> <workdir>"
fi

raw_data=$1
data=$2
lang=$3
src=$4
data_seg=$5
expdir=$6

mkdir -p $data_seg 
mkdir -p ${expdir}

if [ $stage -le 0 ]; then
  LC_ALL= python local/segment_text_by_chapter.py ${raw_data} > ${data_seg}/text
  cat ${data_seg}/text | ./utils/sym2int.pl -f 2- ${lang}/words.txt > ${expdir}/text.int
  #cat ${data_seg}/text | ./utils/sym2int.pl -f 2- ${lang}/words.txt |\
  #  ./utils/apply_map.pl -f 2- <(cut -d' ' -f2- ${lang}/phones/align_lexicon.int) \
  #  > ${expdir}/text.phn.int          
fi

online_ivector_opts=""
if [ ! -z $online_ivector_dir ]; then
  online_ivector_opts="--online-ivector-dir ${online_ivector_dir}" 
fi

if [ $stage -le 1 ]; then
  ./steps/nnet3/align_lats.sh ${online_ivector_opts} \
    --scale-opts "$scale_opts" \
    --acoustic-scale 1.0 \
    --cmd $cmd --nj ${nj} \
    ${data} ${lang} ${src} ${expdir}
fi

if [ $stage -le 2 ]; then
  frameshift=`cat ${src}/frame_subsampling_factor | awk '{s=$0; print s*0.01}'` 
  lattice-align-words-lexicon ${lang}/phones/align_lexicon.int ${src}/final.mdl \
    ark:"gunzip -c ${expdir}/lat.*.gz |" ark:- |\
    lattice-to-ctm-conf --frame-shift=$frameshift ark:- ${expdir}/ctm  
  #ali-to-phones --frame-shift=$frameshift --ctm-output=true\
  #  ${src}/final.mdl ark:"gunzip -c ${expdir}/ali.*.gz |" ${expdir}/ctm  
fi

if [ $stage -le 3 ]; then
  #python local/make_segments_from_ctm_and_ref_text.py \
  #  ${expdir}/text.phn.int ${expdir}/ctm ${data_seg}/segments 
  python local/make_segments_from_ctm_and_ref_text.py \
    ${expdir}/text.int ${expdir}/ctm ${data_seg}/segments 
fi

 
