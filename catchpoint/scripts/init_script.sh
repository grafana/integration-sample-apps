#!/bin/sh

sudo snap install kubectl --classic

# Determine the architecture
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    MINIKUBE_BIN="minikube-linux-amd64"
else
    MINIKUBE_BIN="minikube-linux-arm64"
fi

# Setup Minikube
curl -LO "https://storage.googleapis.com/minikube/releases/latest/$MINIKUBE_BIN"
sudo install $MINIKUBE_BIN /usr/local/bin/minikube
minikube start --memory=12000 --cpus=4 --kubernetes-version=v1.23.17 # Version for Docker support
GATEWAY_IP="$(ip r | grep default | cut -d' ' -f3)"
echo "$GATEWAY_IP catchpoint.k3d.localhost" | sudo tee -a /etc/hosts

sudo snap install helm --classic

# Apply Kubernetes resources for Catchpoint Exporter from the generated_configs directory
kubectl apply -f /catchpoint/config/catchpoint-exporter-deployment.yaml
kubectl apply -f /catchpoint/config/catchpoint-exporter-service.yaml

# Install Grafana Agent Flow
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install grafana-agent-flow grafana/k8s-monitoring -n default --values /catchpoint/config/grafana-flow-k8s-template.yaml
