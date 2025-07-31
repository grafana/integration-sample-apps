#!/bin/bash

set -e

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <vm-name> <hostname>"
  echo "Example: $0 gitlab-vm gitlab.vm"
  exit 1
fi

VM_NAME="$1"
HOSTNAME="$2"

echo "Looking up IP for VM '$VM_NAME'..."
VM_IP=$(multipass info "$VM_NAME" | awk '/IPv4/ { print $2 }')

if [ -z "$VM_IP" ]; then
  echo "Failed to get IP for VM: $VM_NAME"
  exit 1
fi

echo "Updating /etc/hosts with: $VM_IP $HOSTNAME"

# Backup the existing hosts file
sudo cp /etc/hosts /etc/hosts.bak

# Remove any old entry for the hostname
sudo sed -i '' "/[[:space:]]$HOSTNAME$/d" /etc/hosts

# Add the new entry
echo "$VM_IP $HOSTNAME" | sudo tee -a /etc/hosts > /dev/null

echo "Done. You can now access your VM via http://$HOSTNAME"

