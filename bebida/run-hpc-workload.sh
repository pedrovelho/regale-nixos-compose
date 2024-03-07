#!/usr/bin/env bash

set -e
set -x
set -u

su - user1 bash -c '
SIZE=64
RESULTS_DIR=/tmp/shared

export ESPHOME=$(dirname $(dirname $(realpath $(which mkjobmix))))

export ESPSCRATCH=$HOME/expe-$(date -I)
mkdir -p $ESPSCRATCH/logs
mkdir -p $ESPSCRATCH/jobmix
cd $ESPSCRATCH/jobmix

mkjobmix -s $SIZE -b OAR

chmod +x ./*

cd ..

get_result() {
  echo "== Copy results from $ESPSCRATCH to $RESULTS_DIR"
  cp -r $ESPSCRATCH $RESULTS_DIR
}

trap get_result EXIT

runesp -v -b OAR
'
echo Done!
