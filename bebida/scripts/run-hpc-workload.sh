#!/usr/bin/env bash

set -e
set -x
set -u

SIZE=$1
RESULTS_DIR=$2
SPARK_APP=${3:-$HOME/spark-pi.yaml}

export ESPHOME=$(dirname $(dirname $(realpath $(which mkjobmix))))

EXPE_DIR=expe-$(date --iso-8601=minutes | tr ':' '-' | tr '+' '-')
export ESPSCRATCH=$HOME/$EXPE_DIR
mkdir -p $ESPSCRATCH/logs
mkdir -p $ESPSCRATCH/jobmix
cd $ESPSCRATCH/jobmix

mkjobmix -s $SIZE -b OAR

chmod +x ./*

cd ..

get_result() {
  echo "=== Kill HPC workflow submission"
  kill $PID
  echo "\n=== Copy results from $ESPSCRATCH to $RESULTS_DIR"
  mkdir $RESULTS_DIR/$EXPE_DIR
  cp -r $ESPSCRATCH/* $RESULTS_DIR/$EXPE_DIR
  echo === Get all history and logs
  # FIXME Should be enough for this year ^^
  oarstat --gantt "2024-01-01 00:00:00, 2025-01-01 00:00:00" -Jf > $RESULTS_DIR/$EXPE_DIR/oar-jobs.json
  k3s kubectl get events -o json > $RESULTS_DIR/$EXPE_DIR/k8s-events.json
  # Copy this script
  cp "${BASH_SOURCE[0]}" $RESULTS_DIR/$EXPE_DIR/expe-script.sh
  journalctl -u bebida-shaker.service > $RESULTS_DIR/$EXPE_DIR/shaker.log
  echo === Experiment done! 
  echo Results are located here:
  echo $RESULTS_DIR/$EXPE_DIR
}

trap get_result EXIT

k3s kubectl apply -f /etc/demo/spark-setup.yaml

runesp -v -T 10 -b OAR &
PID=$!

for run in seq 5
do
    k3s kubectl apply -f $SPARK_APP
    k3s kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/spark-app-pi --timeout=3600s
    k3s kubectl delete -f $SPARK_APP
    sleep 5
done
echo Done!

