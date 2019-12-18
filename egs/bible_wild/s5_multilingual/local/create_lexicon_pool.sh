#!/bin/bash

. ./path.sh
. ./lexicon.conf

langid=spanish

. ./utils/parse_options.sh

if [ $# -ne 2 ]; then
  echo "Usage: ./local/create_lexicon_pool.sh <wordlist> <odir>"
  exit 1;
fi

wordlist=$1
odir=$2

mkdir -p ${odir}/${langid}

#for l in `cat conf/train.list | awk '{print $1}'`; do
#  LC_ALL= python ./local/prepare_babel_lexicon.py ${!l}      
#done | LC_ALL=C sort -u > ${odir}/lexicon.txt
#
#awk '{print $1}' ${odir}/lexicon.txt | grep -v '<hes>' | grep -v '/[^s]*/' |\
# LC_ALL=C sort -u > ${odir}/words.pool

select_g2p.py \
  --n-order 4 \
  --constraint len \
  --subset-method BatchActive \
  --objective FeatureCoverage \
  --cost-select --binarize-counts \
  --test-wordlist ${wordlist} ${odir}/${langid}/words.txt ${odir}/words.pool 10000 \
  | tee ${odir}/${langid}/select_g2p.log



