#!/bin/bash

. ./path.sh
. ./cmd.sh

langid=multi
affix=
train_nj=32
stage=0
boost_sil=0.5

numLeavesTri1=1000
numGaussTri1=10000
numLeavesTri2=2500
numGaussTri2=36000
numLeavesTri3=5000
numGaussTri3=50000
numLeavesMLLT=10000
numGaussMLLT=100000
numLeavesSAT=20000
numGaussSAT=200000
numLeavesChain=3500

. ./utils/parse_options.sh

# Install uroman for graphemic lexicons
if [ ! -d uroman ]; then 
  echo "Please install uroman: git clone https://github.com/isi-nlp/uroman.git"
  exit 1;
fi

for l in `cat conf/train.list | awk '{print $1}'`; do
  langs+=("$l")    
done

# Data, dict, and lang prep
if [ $stage -le 0 ]; then
  echo "Preparing data"
  for l in ${langs[@]}; do 
    ./local/prepare_bible_data.sh --langid ${l} --affix "${affix}";
  done
fi

if [ $stage -le 1 ]; then
  dicts_and_train=""
  for l in ${langs[@]}; do
    dicts_and_train="data/dict_${l} data/${l}_train ${dicts_and_train}" 
  done
  ./local/prepare_multilingual_data.sh \
    data/lang_${langid} data/${langid}_train exp/${langid} ${dicts_and_train}   
fi

trainset=${langid}_train
traindir=data/${trainset}
langdir=data/lang_${langid}${affix}
# Feature Prep
if [ $stage -le 2 ]; then
  ./steps/make_mfcc_pitch.sh --cmd "$train_cmd" --nj ${train_nj} \
    ${traindir} exp/make_mfcc_pitch/${trainset} mfcc
  ./utils/fix_data_dir.sh ${traindir}
  ./steps/compute_cmvn_stats.sh ${traindir} exp/make_mfcc_pitch/${trainset} mfcc
  ./utils/fix_data_dir.sh ${traindir}
  touch ${traindir}/.mfcc.done
fi

# Subset data for monophone trainin
if [ $stage -le 3 ]; then
  numutt=`cat ${traindir}/feats.scp | wc -l`
  if [ $numutt -gt 5000 ]; then
    local/subset_utts_by_lang.py ${traindir}/segments 5000 ${traindir}/sub1.list     
    utils/subset_data_dir.sh --utt-list ${traindir}/sub1.list ${traindir} ${traindir}_sub1
  else
    (cd data; ln -s ${trainset} ${trainset}_sub1)
  fi
  
  if [ $numutt -gt 10000 ] ; then
    local/subset_utts_by_lang.py ${traindir}/segments 10000 ${traindir}/sub2.list     
    utils/subset_data_dir.sh --utt-list ${traindir}/sub2.list ${traindir} ${traindir}_sub2
  else
    (cd data; ln -s ${trainset} ${trainset}_sub2 )
  fi
  
  if [ $numutt -gt 20000 ] ; then
    local/subset_utts_by_lang.py ${traindir}/segments 20000 ${traindir}/sub3.list     
    utils/subset_data_dir.sh --utt-list ${traindir}/sub3.list ${traindir} ${traindir}_sub3
  else
    (cd data; ln -s ${trainset} ${trainset}_sub3 )
  fi
  touch ${traindir}_sub3/.done
fi

###############################################################################
# HMM-GMM Training
############################################################################### 
if [ $stage -le 4 ]; then
  echo ---------------------------------------------------------------------
  echo "Starting (small) monophone training in exp/mono on" `date`
  echo ---------------------------------------------------------------------
  steps/train_mono.sh \
    --boost-silence $boost_sil --nj 20 --cmd "$train_cmd" \
    ${traindir}_sub1 ${langdir} exp/mono
fi

if [ $stage -le 5 ]; then
  echo ---------------------------------------------------------------------
  echo "Starting (small) triphone training in exp/tri1 on" `date`
  echo ---------------------------------------------------------------------
  steps/align_si.sh \
    --boost-silence $boost_sil --nj 32 --cmd "$train_cmd" \
    ${traindir}_sub2 ${langdir} exp/mono exp/mono_ali_sub2

  steps/train_deltas.sh \
    --boost-silence $boost_sil --cmd "$train_cmd" $numLeavesTri1 $numGaussTri1 \
    ${traindir}_sub2 ${langdir} exp/mono_ali_sub2 exp/tri1

  touch exp/tri1/.done
fi

if [ $stage -le 6 ]; then
  echo ---------------------------------------------------------------------
  echo "Starting (medium) triphone training in exp/tri2 on" `date`
  echo ---------------------------------------------------------------------
  steps/align_si.sh \
    --boost-silence $boost_sil --nj 32 --cmd "$train_cmd" \
    ${traindir}_sub3 ${langdir} exp/tri1 exp/tri1_ali_sub3

  steps/train_deltas.sh \
    --boost-silence $boost_sil --cmd "$train_cmd" $numLeavesTri2 $numGaussTri2 \
    ${traindir}_sub3 ${langdir} exp/tri1_ali_sub3 exp/tri2
  touch exp/tri2/.done
fi

if [ $stage -le 7 ]; then
  echo ---------------------------------------------------------------------
  echo "Starting (full) triphone training in exp/tri3 on" `date`
  echo ---------------------------------------------------------------------
  steps/align_si.sh \
    --boost-silence $boost_sil --nj $train_nj --cmd "$train_cmd" \
    ${traindir} ${langdir} exp/tri2 exp/tri2_ali

  steps/train_deltas.sh \
    --boost-silence $boost_sil --cmd "$train_cmd" \
    $numLeavesTri3 $numGaussTri3 ${traindir} ${langdir} exp/tri2_ali exp/tri3
  touch exp/tri3/.done
fi

if [ $stage -le 8 ]; then
  echo ---------------------------------------------------------------------
  echo "Starting (lda_mllt) triphone training in exp/tri4 on" `date`
  echo ---------------------------------------------------------------------
  #steps/align_si.sh \
  #  --boost-silence $boost_sil --nj $train_nj --cmd "$train_cmd" \
  #  ${traindir} ${langdir} exp/tri3 exp/tri3_ali

  steps/train_lda_mllt.sh \
    --boost-silence $boost_sil --cmd "$train_cmd" \
    $numLeavesMLLT $numGaussMLLT ${traindir} ${langdir} exp/tri3_ali exp/tri4
  touch exp/tri4/.done
fi

if [ $stage -le 9 ]; then
  echo ---------------------------------------------------------------------
  echo "Starting (SAT) triphone training in exp/tri5 on" `date`
  echo ---------------------------------------------------------------------
  steps/align_si.sh \
    --boost-silence $boost_sil --nj $train_nj --cmd "$train_cmd" \
    ${traindir} ${langdir} exp/tri4 exp/tri4_ali

  steps/train_sat.sh \
    --boost-silence $boost_sil --cmd "$train_cmd" \
    $numLeavesSAT $numGaussSAT ${traindir} ${langdir} exp/tri4_ali exp/tri5
  touch exp/tri5/.done
fi

if [ $stage -le 10 ]; then
  echo ---------------------------------------------------------------------
  echo "Starting exp/tri5_ali on" `date`
  echo ---------------------------------------------------------------------
  steps/align_fmllr.sh \
    --boost-silence $boost_sil --nj $train_nj --cmd "$train_cmd" \
    ${traindir} ${langdir} exp/tri5 exp/tri5_ali
  touch exp/tri5_ali/.done
fi

if [ $stage -le 11 ]; then
  echo ---------------------------------------------------------------------
  echo "Starting Chain TDNNF training on" `date`
  echo ---------------------------------------------------------------------
  ./local/run_tdnnf_c.sh \
    --affix 1h_c \
    --train-set ${langid}_train \
    --langdir data/lang_${langid} \
    --num-leaves $numLeavesChain
fi

if [ $stage -le 12 ]; then
  echo ---------------------------------------------------------------------
  echo "Decoding" on `date`
  echo ---------------------------------------------------------------------  
  #for l in `cat conf/test.list conf/train.list | awk '{print $1}'`; do
  for l in `cat conf/debug.list | awk '{print $1}'`; do
    test_langs+=("$l")    
  done
  
  (
    for l in ${test_langs[@]}; do 
      dict=data/dict_${l}${affix} 
      lang=data/lang_${l}
      model=exp/chain/tdnn1h_c_sp   
      if [ ! -d data/${l}_train ]; then
        ./local/prepare_bible_data.sh --langid ${l}
      fi
      
      # Check that there is a trained language model. If not, train one.
      if [ ! -f ${lang}/G.fst ]; then
        ./utils/prepare_lang.sh --share-silence-phones true \
          --phone-symbol-table data/lang_multi/phones.txt \
          ${dict} "<unk>" ${dict}/tmp.lang data/lang_${l}${affix}

        ./local/train_lm.sh ${lang}/words.txt data/${l}_train/text data/${l}_dev/text data/lm_${l}
        ./utils/format_lm.sh ${lang} data/lm_${l}/lm.gz ${dict}/lexicon.txt ${lang}
      fi 
      
      # Check if the decoding graph exists
      if [ ! -d ${model}/graph_${l}${affix} ]; then
        ./utils/mkgraph.sh --self-loop-scale 1.0 ${lang} ${model} ${model}/graph_${l}${affix}
      fi
      
      # Decode the dev and eval sets
      for ds in data/${l}_dev data/${l}_eval; do
        ./local/decode_tdnnf.sh --langid ${l} ${ds} exp/chain/tdnn1h_c_sp   
      done
    done
  ) &
fi
