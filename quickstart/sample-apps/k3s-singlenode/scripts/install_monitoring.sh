#!/bin/sh

# Before anything else, modify the monitoring.yaml file with dns server as reported by the VM
DNSSERVER=$(resolvectl status | grep 'Current DNS Server: ' | grep -o -E '[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}')
sed -i "s/placeholder_dns_ip/${DNSSERVER}/" monitoring.yaml

# Re-set the KUBECONFIG since multipass exec does not load .profile or .bashrc correctly
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Install Grafana helm repo
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install k8s monitoring chart with `extraConfig` for the suo (Pinned to v1 helm chart)
helm install k8s-monitoring grafana/k8s-monitoring -n monitoring --create-namespace --wait --values monitoring.yaml --set-file extraConfig=configs/suo.alloy --version ^1
