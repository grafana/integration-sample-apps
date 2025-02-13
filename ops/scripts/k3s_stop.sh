#!/bin/bash

echo "-- Destroying k3s environment for $1 --"

multipass stop $1-k3s-main
multipass delete $1-k3s-main

if [[ "$2" = "cluster" ]]; then
    echo "-- Cluster mode, tearing down worker nodes --"
    multipass stop $1-k3s-worker-1 $1-k3s-worker-2
    multipass delete $1-k3s-worker-1 $1-k3s-worker-2
fi

multipass purge
