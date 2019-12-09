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

. ./path.sh
. ./cmd.sh
. ./lang.conf

langid=spanish
stage=0
nj=50
src=exp/chain/tdnn2h_a_sp

. ./utils/parse_options.sh

# Run Monolingual ASR first. We generall assume these already
# exist. This part takes a few hours
if [ $stage -le -1 ]; then
  ./run.sh --langid ${langid}
fi

# Creates data/${langid}_long{,_hires}, data/dict_${langid}_long and
# data/lang_${langid}_long. It also creates ivectors data/ivectors_{langid}_long_hires
if [ $stage -le 0 ]; then
  ./local/prepare_long_data.sh --langid ${langid}
fi

# Create the verse aligned data directory (suitable for speech translation) 
if [ $stage -le 1 ]; then
  ./local/align_by_verse_nnet3.sh --cmd "$train_cmd" --nj ${nj} \
    --online-ivector-dir data/ivectors_${langid}_long_hires \
   ${!langid}/download/txt data/${langid}_long_hires data/lang_${langid}_long \
   ${src} data/${langid}_verse exp/segment_verse 
fi

