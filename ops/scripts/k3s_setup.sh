#!/bin/bash
# Ensure this script execcutes from ops/scripts regardless of where its invoked from
cd "$(dirname "$0")"


echo "-- Spinning up k3s environment for $1 --"
# Spawn nodes to build k3s (cluster) with
multipass launch -n $1-k3s-main -c 4 -m 6G -d 20G --cloud-init ../qa/k3s-main-cloud-init.yaml

if [[ "$2" = "cluster" ]]; then
    echo "-- Cluster mode, spawning worker nodes --"
    # Split from later config so the worker nodes have a little extra time to initialise
    multipass launch -n $1-k3s-worker-1 -c 2 -m 6G -d 20G
    multipass launch -n $1-k3s-worker-2 -c 2 -m 6G -d 20G
fi


# Get token and IP of main node
TOKEN=$(multipass exec $1-k3s-main sudo cat /var/lib/rancher/k3s/server/node-token)
IP=$(multipass info $1-k3s-main | grep IPv4 | awk '{print $2}')

if [[ "$2" = "cluster" ]]; then
    for i in $(seq 1 2)
    do 
        echo "-- Installing & configuring k3s on worker node $i --"
        multipass exec $1-k3s-worker-$i -- bash -c "curl -sfL https://get.k3s.io | K3S_URL=\"https://$IP:6443\" K3S_TOKEN=\"$TOKEN\" sh -"
    done
fi
