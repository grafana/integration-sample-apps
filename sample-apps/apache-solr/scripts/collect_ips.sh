#!/bin/bash

VM_PREFIX="apache-solr-zookeeper-instance"
> vms_ips.txt

# Get IP addresses of VMs
for i in 1 2 3; do
    IP=$(multipass info "${VM_PREFIX}-$i" --format json | jq -r ".info.\"${VM_PREFIX}-$i\".ipv4[0]")
    echo "$IP" >> vms_ips.txt
done
