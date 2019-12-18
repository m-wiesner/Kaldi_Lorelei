#!/bin/bash

. ./path.sh
. ./lang.conf
. ./cmd.sh

langid=spanish
extractor=../s5/exp/nnet3/extractor
stage=0

. ./utils/parse_options.sh

echo "data/dict_${langid}_long"

data=${!langid}
wordlists=data/local/${langid}/text

langdata=data/${langid}_long
mkdir -p ${langdata}

#Make wav.scp
if [ $stage -le 0 ]; then
  files=( `find -L ${data}/wav -name *.mp3` )
  for f in ${files[@]}; do
    fname=`basename $f`
    fname=${fname%%.mp3}
    echo "${fname} ffmpeg -v 8 -i ${f} -f wav -acodec pcm_s16le - | sox -t wav - -r 16000 -c 1 -t wav -|"
  done | sort > ${langdata}/wav.scp
  
  # Make utt2spk and spk2utt
  awk '{print $1" "$1}' ${langdata}/wav.scp > ${langdata}/utt2spk
  ./utils/spk2utt_to_utt2spk.pl ${langdata}/utt2spk > ${langdata}/spk2utt
  
  # Make text 
  wordlists=data/local/${langid}/text
  mkdir -p ${wordlists}
  echo "Searching in ${data} for text ..."
  LC_ALL= python local/segment_text_by_chapter.py --chapter-segs ${data}/download/txt > ${langdata}/text
fi

if [ $stage -le 1 ]; then
  # Get training words
  dict=data/dict_${langid}_long
  mkdir -p ${dict}
  cut -d' ' -f2- ${langdata}/text | tr " " "\n" | sort -u |\
    grep -v '<unk>' | grep -v '^\s*$' > ${dict}/words
  LC_ALL= python ./local/filter.py ${dict}/words ${dict}/vocab 
  #grep -v '[0-9]' | grep -v '<unk>' | grep -v '^\s*$' > ${dict}/words
  paste -d' ' <(awk '{print $1}' ${dict}/vocab) \
    <(uroman/bin/uroman.pl < ${dict}/words | LC_ALL= sed 's/./& /g') | sort |\
    cat <(echo -e "<unk> SIL") - > ${dict}/lexicon.txt  

  ./local/prepare_dict.py --silence-lexicon <(echo -e "<unk> SIL") ${dict}/lexicon.txt ${dict}
  ./utils/prepare_lang.sh --share-silence-phones true ${dict} "<unk>" ${dict}/tmp.lang data/lang_${langid}_long
fi

if [ $stage -le 2 ]; then
  dataname=`basename ${langdata}_hires`
  ./utils/copy_data_dir.sh ${langdata} ${langdata}_hires
  ./steps/make_mfcc.sh --nj 32 --mfcc-config conf/mfcc_hires.conf --cmd "$train_cmd" ${langdata}_hires
  ./steps/compute_cmvn_stats.sh ${langdata}_hires
  ./utils/fix_data_dir.sh ${langdata}_hires
  
  ./steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj 20 \
      ${langdata}_hires ${extractor} data/ivectors_${dataname}
fi
