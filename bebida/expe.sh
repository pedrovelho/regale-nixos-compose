#!/usr/bin/env bash

set -e
set -x
set -u

SIZE=${SIZE:-2}

export ESPHOME=$(dirname $(dirname $(realpath $(which mkjobmix))))

export ESPSCRATCH=$HOME/expe-$(date -I)

mkjobmix -s $SIZE -b OAR-BEBIDA

runesp -v -b OAR-BEBIDA

echo Done!
