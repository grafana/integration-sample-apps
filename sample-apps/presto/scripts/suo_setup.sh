#!/bin/sh

# Re-set the KUBECONFIG since multipass exec does not load .profile or .bashrc correctly
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

helm repo add presto https://prestodb.github.io/presto-helm-charts
helm repo update

kubectl create namespace presto --dry-run=client -o yaml | kubectl apply -f -

# Install Presto
helm install presto presto/presto -n presto \
    --create-namespace \
    --values /home/ubuntu/configs/values.yaml \
    --wait \
    --version 0.4.0

kubectl apply -f /home/ubuntu/configs/loadgen.yaml -n presto
