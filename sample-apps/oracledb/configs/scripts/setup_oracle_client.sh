#!/bin/bash

# Setup Oracle Instant Client in PVC
# This script sets up the Oracle Instant Client libraries into the PVC

set -e

echo "Setting up Oracle Instant Client..."

# Re-set the KUBECONFIG since multipass exec does not load .profile or .bashrc correctly
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

cd /home/ubuntu/configs

# Create namespace for monitoring
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f oracle-instant-client-pvc.yaml -n monitoring

echo "Running Oracle Instant Client setup job..."
kubectl apply -f oracle-instant-client-setup-job.yaml -n monitoring

echo "Waiting for Oracle Instant Client setup to complete..."
kubectl wait --for=condition=complete job/oracle-instant-client-setup -n monitoring --timeout=90s

echo "Checking setup status..."
kubectl logs job/oracle-instant-client-setup -n monitoring

echo "Oracle Instant Client setup completed successfully!"

# Cleanup the job
echo "Cleaning up setup job..."
kubectl delete job oracle-instant-client-setup -n monitoring

echo "Oracle Instant Client is now ready for Alloy to use in the PVC"
