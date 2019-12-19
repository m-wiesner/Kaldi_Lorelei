#!/bin/bash

. ./path.sh
. ./lang.conf
. ./cmd.sh

langid=spanish
affix=
lexicon=

. ./utils/parse_options.sh

echo "AFFIX: ${affix}"
echo "data/dict_${langid}${affix}"

langdata=${!langid}
wordlists=data/local/${langid}/text

echo ${charset}

datadir=data/${langid}
mkdir -p ${datadir}

echo "Lang data: ${langdata}"

#Make wav.scp
files=( `find -L ${langdata}/wav -name "*.mp3"` )
for f in ${files[@]}; do
  fname=`basename $f`
  fname=${fname%%.mp3}
  echo "${fname} ffmpeg -v 8 -i ${f} -f wav -acodec pcm_s16le - | sox -t wav - -r 16000 -c 1 -t wav -|"
  # sox should work, but it sometimes doesn't have mp3 support. 
  #echo "${fname} sox ${f} -t wav -r 16000 -|"
done | sort > ${datadir}/wav.scp

# Get segments file
awk '{print $2,$1,$3,$4}' ${langdata}/asr_files/segments > ${datadir}/segments

# Make utt2spk and spk2utt
awk '{print $1" "$1}' ${datadir}/segments > ${datadir}/utt2spk
./utils/spk2utt_to_utt2spk.pl ${datadir}/utt2spk > ${datadir}/spk2utt

# Make text 
mkdir -p ${wordlists}
echo "Searching in ${langdata} for text ..."
find ${langdata}/download/txt -name "*.txt" > ${wordlists}/${langid}_files.scp
./local/unicode_filter_punct.py data/local/${langid}/text/${langid}_files.scp data/local/${langid}/text/text

# Get tokens and filter out numbers so that they will become unk
cut -d' ' -f2- data/local/${langid}/text/text | ngram-count -order 1 -text - -write data/local/${langid}/text/tokens
./local/filter.py data/local/${langid}/text/tokens data/local/${langid}/text/vocab
awk '{print $1}' data/local/${langid}/text/vocab > data/local/${langid}/text/words

localdict=data/local/${langid}/dict_${langid}${affix}
mkdir -p $localdict
if [ ! -z $lexicon ]; then 
  LC_ALL= python local/prepare_babel_lexicon.py ${lexicon} > ${localdict}/lexicon.raw 
  ./local/transform_4_g2p.py ${localdict}/lexicon.raw ${localdict}/transformed_lexicon.txt
  ./local/train_g2p.sh ${localdict}/transformed_lexicon.txt exp/g2p_${langid} exp/g2p_${langid}/bible_words
  ./local/apply_g2p.sh data/local/${langid}/text/words exp/g2p_${langid} exp/g2p_${langid}/bible_words
  
  awk -F '\t' '(NR==FNR){a[$1]=$0; next} {if($1 in a){print a[$1]}else{print $1"\t"$3}}' \
    ${localdict}/transformed_lexicon.txt exp/g2p_${langid}/bible_words/lexicon_out.1 \
    | awk '(NF>1)' > ${localdict}/lexicon.txt   
else
  paste -d' ' data/local/${langid}/text/words \
    <(uroman/bin/uroman.pl < data/local/${langid}/text/words | LC_ALL= sed 's/./& /g') \
    | sort > ${localdict}/lexicon.txt
fi

LC_ALL= python local/clean_transcript.py \
  ${!langid}/asr_files/transcription_nopunc.txt ${localdict}/lexicon.txt \
  > ${datadir}/text


# Make splits
echo "Using user specified subsets ..."
cp -r ${datadir} ${datadir}_train
cp -r ${datadir} ${datadir}_dev
cp -r ${datadir} ${datadir}_eval

grep -f dev.list ${datadir}/text | cut -f1  > data/local/${langid}/dev.keys
grep -f eval.list ${datadir}/text | cut -f1 > data/local/${langid}/eval.keys

dev_keys=data/local/${langid}/dev.keys
eval_keys=data/local/${langid}/eval.keys

./utils/filter_scp.pl --exclude -f 1 $dev_keys ${datadir}/text > ${datadir}_train/text.nodev 
./utils/filter_scp.pl --exclude -f 1 $eval_keys ${datadir}_train/text.nodev > ${datadir}_train/text
./utils/filter_scp.pl -f 1 $dev_keys ${datadir}/text > ${datadir}_dev/text 
./utils/filter_scp.pl -f 1 $eval_keys ${datadir}/text > ${datadir}_eval/text 

./utils/fix_data_dir.sh ${datadir}_train
./utils/fix_data_dir.sh ${datadir}_dev
./utils/fix_data_dir.sh ${datadir}_eval

# Get training words
dict=data/dict_${langid}${affix}
mkdir -p ${dict}
cut -f2- ${datadir}_train/text | tr " " "\n" | sort -u |\
  awk '(NR==FNR){a[$1]=1; next} ($1 in a){print $0}' - ${localdict}/lexicon.txt \
  | cat <(echo -e "<unk> SIL") - > ${dict}/lexicon.txt 

./local/prepare_dict.py --silence-lexicon <(echo -e "<unk> SIL") ${dict}/lexicon.txt ${dict}
