#!/bin/bash

if [ $# -ne 1 ]; then
  echo "Usage: ./setup_multilingual_experiment.sh <name>"
  exit 1;
fi

name=$1

mkdir -p $name
cp -r s5_multilingual/{local,conf} $name

# Softlink uroman in case it is already downloaded
if [ -d s5_multilingual/uroman ]; then
  ln -s ../s5/uroman ${name}/uroman
fi

cp -P s5_multilingual/{steps,utils} ${name}/
cp s5_multilingual/{run.sh,eval.list,dev.list,path.sh,cmd.sh,lang.conf,lexicon.conf} ${name} 
