#!/bin/bash

. ./utils/parse_options.sh

if [ $# -ne 2 ]; then
  echo "Usage: ./local/list_to_conf.sh <data> <list>"
  exit 1;
fi

data=$1
list=$2

# List has form:
# 
# langid1 langcode1
# langid2 langcode2
# ...

echo "data=${data}"
awk '{print $1"=${data}/"$2}' $list
