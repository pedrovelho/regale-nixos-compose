#!/usr/bin/env bash

set -x
set -e

(
export PATH=/run/current-system/sw/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export KUBECONFIG=/etc/bebida/kubeconfig.yaml

printenv

export SLURM_NODELIST=$SLURM_JOB_NODELIST
for node in $(scontrol show hostnames)
do
        kubectl uncordon --insecure-skip-tls-verify $node
done
) > /etc/bebida/log/${SLURM_JOB_ID}-epilog-logs 2> /etc/bebida/log/${SLURM_JOB_ID}-epilog-logs
