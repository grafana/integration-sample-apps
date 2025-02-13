#!/bin/sh

# Re-set the KUBECONFIG since multipass exec does not load .profile or .bashrc correctly
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Install Grafana helm repo
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install k8s monitoring chart with `extraConfig` for kafka (Pinned to v1 helm chart)
helm install k8s-monitoring grafana/k8s-monitoring -n monitoring --create-namespace --wait --values monitoring.yaml --set-file extraConfig=configs/kafka.alloy --version ^1
