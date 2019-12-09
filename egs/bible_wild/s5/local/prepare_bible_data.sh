#!/bin/bash

. ./path.sh
. ./lang.conf
. ./cmd.sh

langid=spanish
affix=

. ./utils/parse_options.sh

echo "AFFIX: ${affix}"
echo "data/dict_${langid}${affix}"

data=${!langid}
wordlists=data/local/${langid}/text

echo ${charset}

langdata=data/${langid}
mkdir -p ${langdata}

#Make wav.scp
files=( `find -L ${data}/aligned/wav -name *.wav` )
for f in ${files[@]}; do
  fname=`basename $f`
  fname=${fname%%.wav}   
  echo "${fname} sox ${f} -t wav -r 16000 -|"
done | sort > ${langdata}/wav.scp

# Make utt2spk and spk2utt
awk '{print $1" "$1}' ${langdata}/wav.scp > ${langdata}/utt2spk
./utils/spk2utt_to_utt2spk.pl ${langdata}/utt2spk > ${langdata}/spk2utt

# Make text 
mkdir -p ${wordlists}
echo "Searching in ${data} for text ..."
find ${data}/download/txt -name "*.txt" > ${wordlists}/${langid}_files.scp
./local/unicode_filter_punct.py data/local/${langid}/text/${langid}_files.scp data/local/${langid}/text/text

# Get tokens and filter by script
cut -d' ' -f2- data/local/${langid}/text/text | ngram-count -order 1 -text - -write data/local/${langid}/text/tokens
./local/filter.py data/local/${langid}/text/tokens data/local/${langid}/text/vocab
awk '{print $1}' data/local/${langid}/text/vocab > data/local/${langid}/text/words

LC_ALL= python local/clean_transcript.py \
  ${!langid}/asr_files/transcription_nopunc.txt data/local/${langid}/text/words \
  > ${langdata}/text

localdict=data/local/${langid}/dict_${langid}${affix}
mkdir -p $localdict
paste -d' ' data/local/${langid}/text/words \
  <(uroman/bin/uroman.pl < data/local/${langid}/text/words | LC_ALL= sed 's/./& /g') \
  | sort > ${localdict}/lexicon.txt

# Make splits
echo "Using user specified subsets ..."
cp -r ${langdata} ${langdata}_train
cp -r ${langdata} ${langdata}_dev
cp -r ${langdata} ${langdata}_eval

grep -f dev.list ${langdata}/text | cut -f1  > data/local/${langid}/dev.keys
grep -f eval.list ${langdata}/text | cut -f1 > data/local/${langid}/eval.keys

dev_keys=data/local/${langid}/dev.keys
eval_keys=data/local/${langid}/eval.keys

./utils/filter_scp.pl --exclude -f 1 $dev_keys ${langdata}/text > ${langdata}_train/text.nodev 
./utils/filter_scp.pl --exclude -f 1 $eval_keys ${langdata}_train/text.nodev > ${langdata}_train/text
./utils/filter_scp.pl -f 1 $dev_keys ${langdata}/text > ${langdata}_dev/text 
./utils/filter_scp.pl -f 1 $eval_keys ${langdata}/text > ${langdata}_eval/text 

./utils/fix_data_dir.sh ${langdata}_train
./utils/fix_data_dir.sh ${langdata}_dev
./utils/fix_data_dir.sh ${langdata}_eval

# Get training words
dict=data/dict_${langid}${affix}
mkdir -p ${dict}
cut -f2- ${langdata}_train/text | tr " " "\n" | sort -u |\
  awk '(NR==FNR){a[$1]=1; next} ($1 in a){print $0}' - ${localdict}/lexicon.txt \
  | cat <(echo -e "<unk> SIL") - > ${dict}/lexicon.txt 

./local/prepare_dict.py --silence-lexicon <(echo -e "<unk> SIL") ${dict}/lexicon.txt ${dict}
./utils/prepare_lang.sh --share-silence-phones true ${dict} "<unk>" ${dict}/tmp.lang data/lang_${langid}${affix}
