#!/bin/bash

. ./path.sh
. ./cmd.sh

affix=
langid=spanish
extractor=exp/nnet3/extractor
stage=0

. ./utils/parse_options.sh

if [ $# -ne 2 ]; then
  echo "Usage: ./local/prepare_recog.sh <data> <modeldir>"
  echo ""
  echo "The decode directory is automatically created in ${model}/decode_graph${affix}_${dataname}" 
  exit 1;
fi

data=$1
model=$2

lang=data/lang_${langid}
# Check that there is a trained language model. If not, train one.
if [ ! -f ${lang}/G.fst ]; then
  ./local/train_lm.sh ${lang}/words.txt data/${langid}_train/text data/${langid}_dev/text data/lm_${langid}
  ./utils/format_lm.sh ${lang} data/lm_${langid}/lm.gz data/dict_${langid}/lexicon.txt ${lang}
fi 

if [ ! -d ${model}/graph ]; then
  ./utils/mkgraph.sh --self-loop-scale 1.0 ${lang} ${model} ${model}/graph${affix}
fi

dataname=`basename ${data}_hires`
if [ $stage -le 1 ]; then
  # Compute HIRES MFCCs
  ./utils/copy_data_dir.sh ${data} ${data}_hires
  ./steps/make_mfcc.sh --nj 32 --mfcc-config conf/mfcc_hires.conf --cmd "$train_cmd" ${data}_hires
  ./steps/compute_cmvn_stats.sh ${data}_hires
  ./utils/fix_data_dir.sh ${data}_hires

  # Extract IVectors
  ./steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj 20 \
    ${data}_hires ${extractor} data/ivectors_${dataname}
fi

if [ $stage -le 2 ]; then
  ./steps/nnet3/decode.sh --acwt 1.0 --post-decode-acwt 10.0 --nj 50 \
    --cmd "$decode_cmd" --skip-scoring true --online-ivector-dir data/ivectors_${dataname}\
    ${model}/graph${affix} ${data}_hires ${model}/decode_graph${affix}_${dataname}
  
  ./steps/score_kaldi.sh --cmd "$decode_cmd" \
    --min-lmwt 14 --max-lmwt 23 \
    ${data} ${model}/graph${affix} ${model}/decode_graph${affix}_${dataname}
fi

grep WER ${model}/decode_graph${affix}_${dataname}/scoring_kaldi/best_wer
grep WER ${model}/decode_graph${affix}_${dataname}/scoring_kaldi/wer_details/wer_bootci

exit 0;
