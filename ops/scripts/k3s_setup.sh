#!/bin/bash
# Save the original directory where script was called from
ORIGINAL_DIR=$(pwd)

cd "$(dirname "$0")"

# Set default hardware requirements for primary node
PRIMARY_CPU="4" # Cores
PRIMARY_MEMORY="6" # GB
PRIMARY_DISK="20" # GB

# Set default hardware requirements for worker nodes
WORKER_CPU="2" # Cores
WORKER_MEMORY="6" # GB
WORKER_DISK="20" # GB

# Check for HARDWARE_REQUIREMENTS file in the calling directory
if [[ -f "$ORIGINAL_DIR/.hardware_requirements" ]]; then
    echo "-- Found .hardware_requirements file in $ORIGINAL_DIR, reading configuration --"
    # Source the file to get MEMORY and DISK values
    source "$ORIGINAL_DIR/.hardware_requirements"
    echo "-- Using PRIMARY_CPU=${PRIMARY_CPU}C, PRIMARY_MEMORY=${PRIMARY_MEMORY}G, PRIMARY_DISK=${PRIMARY_DISK}G, WORKER_CPU=${WORKER_CPU}C, WORKER_MEMORY=${WORKER_MEMORY}G, WORKER_DISK=${WORKER_DISK}G --"
fi

echo "-- Spinning up k3s environment for $1 --"
# Launch the primary k3s node with configurable hardware requirements
multipass launch -n $1-k3s-main -c ${PRIMARY_CPU} -m ${PRIMARY_MEMORY}G -d ${PRIMARY_DISK}G --cloud-init ../qa/k3s-main-cloud-init.yaml

if [[ "$2" = "cluster" ]]; then
    echo "-- Cluster mode, spawning worker nodes --"
    # Launch worker nodes with fixed hardware requirements
    multipass launch -n $1-k3s-worker-1 -c ${WORKER_CPU} -m ${WORKER_MEMORY}G -d ${WORKER_DISK}G
    multipass launch -n $1-k3s-worker-2 -c ${WORKER_CPU} -m ${WORKER_MEMORY}G -d ${WORKER_DISK}G
fi


# Get token and IP of main node for worker node configuration
TOKEN=$(multipass exec $1-k3s-main sudo cat /var/lib/rancher/k3s/server/node-token)
IP=$(multipass info $1-k3s-main | grep IPv4 | awk '{print $2}')

if [[ "$2" = "cluster" ]]; then
    for i in $(seq 1 2)
    do 
        echo "-- Installing & configuring k3s on worker node $i --"
        multipass exec $1-k3s-worker-$i -- bash -c "curl -sfL https://get.k3s.io | K3S_URL=\"https://$IP:6443\" K3S_TOKEN=\"$TOKEN\" sh -"
    done
fi
