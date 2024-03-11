#!/usr/bin/env bash

set -e
set -x
set -u

SIZE=$1
RESULTS_DIR=$2

export ESPHOME=$(dirname $(dirname $(realpath $(which mkjobmix))))

EXPE_DIR=expe-$(date --iso-8601=hours)
export ESPSCRATCH=$HOME/$EXPE_DIR
mkdir -p $ESPSCRATCH/logs
mkdir -p $ESPSCRATCH/jobmix
cd $ESPSCRATCH/jobmix

mkjobmix -s $SIZE -b OAR

chmod +x ./*

cd ..

get_result() {
  mkdir -p $RESULTS_DIR/$EXPE_DIR/app
  echo "\n== Copy results from $ESPSCRATCH to $RESULTS_DIR"
  cp -r $ESPSCRATCH $RESULTS_DIR/$EXPE_DIR
  echo == Get OAR history
  # FIXME Should be enough for this year ^^
  oarstat --gantt "2024-01-01 00:00:00, 2025-01-01 00:00:00" -Jf > $RESULTS_DIR/oar-jobs.json
}

trap get_result EXIT

runesp -v -b OAR
echo Done!
