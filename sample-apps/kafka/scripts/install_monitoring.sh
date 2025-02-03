#!/bin/sh

# Re-set the KUBECONFIG since multipass exec does not load .profile or .bashrc correctly
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Install k8s monitoring chart with `extraConfig` for kafka
helm install k8s-monitoring grafana/k8s-monitoring -n monitoring --create-namespace --wait --values monitoring.yaml --set-file extraConfig=suo.river --version ^1