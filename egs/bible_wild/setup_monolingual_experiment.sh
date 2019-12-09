#!/bin/bash

if [ $# -ne 1 ]; then
  echo "Usage: ./setup_monolingual_experiment.sh <name>"
  exit 1;
fi

name=$1

mkdir -p $name
cp -r s5/{local,conf} $name

# Softlink uroman in case it is already downloaded
if [ -d s5/uroman ]; then
  ln -s ../s5/uroman ${name}/uroman
fi

cp -P s5/{steps,utils} ${name}/
cp s5/{run.sh,eval.list,dev.list,path.sh,cmd.sh,lang.conf} ${name} 
