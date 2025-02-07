#!/bin/bash

echo "Destroying k3s environment for $1"
multipass stop $1-k3s-main $1-k3s-worker-1 $1-k3s-worker-2
multipass delete $1-k3s-main $1-k3s-worker-1 $1-k3s-worker-2
multipass purge
