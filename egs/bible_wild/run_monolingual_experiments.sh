#!/bin/bash

for l in $@; do
  (
    cd $l
    echo ${l}
    ./run.sh --langid ${l}
  ) & 
done


