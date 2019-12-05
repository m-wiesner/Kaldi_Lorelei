#!/bin/bash

. ./path.sh
. ./cmd.sh

langid=spanish
affix=
train_nj=32
stage=1
boost_sil=0.5

numLeavesTri1=1000
numGaussTri1=10000
numLeavesTri2=2500
numGaussTri2=36000
numLeavesTri3=2500
numGaussTri3=36000
numLeavesMLLT=2500
numGaussMLLT=36000
numLeavesSAT=2500
numGaussSAT=36000

. ./utils/parse_options.sh

# Install uroman for graphemic lexicons
if [ ! -d uroman ]; then 
  echo "Please install uroman: git clone https://github.com/isi-nlp/uroman.git"
  exit 1;
fi

# Data, dict, and lang prep
if [ $stage -le 1 ]; then
  echo "Preparing data"
  ./local/prepare_bible_data.sh --langid ${langid} --affix "${affix}"
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
    utils/subset_data_dir.sh ${traindir} 5000 ${traindir}_sub1
  else
    (cd data; ln -s ${trainset} ${trainset}_sub1)
  fi
  
  if [ $numutt -gt 10000 ] ; then
    utils/subset_data_dir.sh ${traindir} 10000 ${traindir}_sub2
  else
    (cd data; ln -s ${trainset} ${trainset}_sub2 )
  fi
  
  if [ $numutt -gt 20000 ] ; then
    utils/subset_data_dir.sh ${traindir} 20000 ${traindir}_sub3
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
  steps/align_si.sh \
    --boost-silence $boost_sil --nj $train_nj --cmd "$train_cmd" \
    ${traindir} ${langdir} exp/tri3 exp/tri3_ali

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

exit 0;
