#!/bin/bash

. ./path.sh

langid=spanish

. ./utils/parse_options.sh

if [ $# -ne 2 ]; then
  echo "Usage: ./local/prepare_xlingual_lexicon.sh <wordlist> <odir>"
  exit 1;
fi

wordlist=$1
odir=$2

mkdir -p ${odir}/${langid}

for l in `cat conf/train.list | awk '{print $1}'`; do
  lex=data/local/${l}/dict_${l}/transformed_lexicon.txt
  [ -f ${lex} ] || (echo "${lex} does not exist..." && exit 1);
  lexicons+=("$lex") 
done

cat ${lexicons[@]} | LC_ALL=C sort -u > ${odir}/lexicon.txt
cat ${odir}/lexicon.txt | awk -F '\t' '{print $1}' |\
  LC_ALL=C sort -u > ${odir}/words.pool

select_g2p.py \
  --n-order 4 \
  --constraint len \
  --subset-method BatchActive \
  --objective FeatureCoverage \
  --cost-select --binarize-counts \
  --test-wordlist ${odir}/words.pool ${odir}/${langid}/words.txt ${wordlist} 10000 \
  | tee ${odir}/${langid}/select_g2p.log

awk '(NR==FNR) {
    counts[$1]+=1;
    a[$1][counts[$1]]=$0;
    next
    } 
    ($1 in a) {
      for (i in a[$1]) {
        print a[$1][i]
      }
    }' ${odir}/lexicon.txt ${odir}/${langid}/words.txt > ${odir}/${langid}/lexicon.txt

exit 0;
