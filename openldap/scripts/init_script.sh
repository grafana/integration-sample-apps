#!/bin/sh

sudo snap install kubectl --classic

# Get the architecture
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    MINIKUBE_BIN="minikube-linux-amd64"
else
    MINIKUBE_BIN="minikube-linux-arm64"
fi

# Setup minikube
curl -LO "https://storage.googleapis.com/minikube/releases/latest/$MINIKUBE_BIN"
sudo install $MINIKUBE_BIN /usr/local/bin/minikube
minikube start --memory=12000 --cpus=4 --kubernetes-version=v1.23.17 # Last version that fully supported docker
GATEWAY_IP="$(ip r | grep default | cut -d' ' -f3)"
echo "$GATEWAY_IP grafana.k3d.localhost loki.k3d.localhost mimir.k3d.localhost" | sudo tee -a /etc/hosts

sudo snap install helm --classic

# Install OpenLDAP
helm repo add helm-openldap https://jp-gouin.github.io/helm-openldap/
helm repo update
kubectl create namespace openldap
helm install my-openldap jp-gouin/openldap -n openldap -f ldap-server/cloud/my-openldap-values.yaml

# Apply other Kubernetes resources for OpenLDAP
kubectl apply -f ldap-serer/cloud/openldap_exporter_deployment.yaml
kubectl apply -f ldap-serer/cloud/openldap_exporter_service.yaml
kubectl apply -f ldap-serer/cloud/openldap_service.yaml

# Install Grafana Agent Flow
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update


helm install grafana-agent-flow grafana/k8s-monitoring -n openldap --values /ldap-server/config/grafana-flow-k8s-template.yaml
