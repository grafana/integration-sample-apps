#!/bin/sh
sudo snap install helm --classic
sudo snap install kubectl --classic

# Get the architecture
ARCH=$(uname -m)
if [ "$ARCH" == "x86_64" ]; then
    MINIKUBE_BIN="minikube-linux-amd64"
else
    MINIKUBE_BIN="minikube-linux-arm64"
fi

# Setup minikube
curl -LO "https://storage.googleapis.com/minikube/releases/latest/$MINIKUBE_BIN"
sudo install $MINIKUBE_BIN /usr/local/bin/minikube
minikube start --memory=12000 --cpus=4 --kubernetes-version=v1.23.17

# Download velero
sudo mv /grafana-agent-flow.yaml ~
sudo wget https://github.com/vmware-tanzu/velero/releases/download/v1.13.1/velero-v1.13.1-linux-arm64.tar.gz
sudo tar -xvf velero-v1.13.1-linux-arm64.tar.gz
sudo mv ./velero-v1.13.1-linux-arm64/velero /usr/local/bin

# Add helm repos
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Install velero
export BUCKET=$(cat /home/ubuntu/jinja/variables/bucket.txt)
velero install --provider gcp --bucket $BUCKET --secret-file /home/ubuntu/jinja/variables/gcp_credentials.json --plugins velero/velero-plugin-for-gcp:v1.8.0 

# Install nginx and grafana-agent
helm install my-nginx bitnami/nginx --version 15.14.0 --create-namespace --namespace demo-0
helm install my-nginx bitnami/nginx --version 15.14.0 --create-namespace --namespace demo-1
helm install grafana-agent-flow grafana/k8s-monitoring -n velero --values grafana-agent-flow.yaml

sudo chmod +x /velero/scripts/load-gen.sh

echo "*/10 * * * * /velero/scripts/load-gen.sh" | crontab -

sleep 20
