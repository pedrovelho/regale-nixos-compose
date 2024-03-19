#!/usr/bin/env bash

set -e
set -x
set -u

SIZE=$1
RESULTS_DIR=$2

export ESPHOME=$(dirname $(dirname $(realpath $(which mkjobmix))))

EXPE_DIR=expe-$(date --iso-8601=hours | tr ':' '-' | tr '+' '-')
export ESPSCRATCH=$HOME/$EXPE_DIR
mkdir -p $ESPSCRATCH/logs
mkdir -p $ESPSCRATCH/jobmix
cd $ESPSCRATCH/jobmix

mkjobmix -s $SIZE -b OAR

chmod +x ./*

cd ..

get_result() {
  echo "\n== Copy results from $ESPSCRATCH to $RESULTS_DIR"
  cp -r $ESPSCRATCH $RESULTS_DIR/$EXPE_DIR
  echo == Get all history and logs
  # FIXME Should be enough for this year ^^
  oarstat --gantt "2024-01-01 00:00:00, 2025-01-01 00:00:00" -Jf > $RESULTS_DIR/$EXPE_DIR/oar-jobs.json
  k3s kubectl get events -o json > $RESULTS_DIR/$EXPE_DIR/k8s-events.json
  journalctl -u bebida-shaker.service > $RESULTS_DIR/$EXPE_DIR/shaker.log
}

trap get_result EXIT

kubectl apply -f /etc/demo/spark-setup.yaml

runesp -v -T 10 -b OAR &

for run in seq 5
do
    kubectl apply -f /etc/demo/spark-pi.yaml
    kubectl wait --for=condition=Completed pod/spark-app-pi
    sleep 5
done
echo Done!

