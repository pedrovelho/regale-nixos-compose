#!/bin/bash
export OAR_JOB_ID=$1
export PATH=$PATH:/run/current-system/sw/bin:/run/wrappers/bin
(
echo BEBIDA epilog

printenv
id

for node in $(oarstat -J -j "$OAR_JOB_ID" -p | jq ".[\"$OAR_JOB_ID\"][] | .network_address" -r)
do
  echo == Adding node $node
  oardodo kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml uncordon $node
  echo == Added node $node
done
) > /tmp/oar-${OAR_JOB_ID}-epilog-logs 2> /tmp/oar-${OAR_JOB_ID}-epilog-logs
