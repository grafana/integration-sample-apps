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

sudo mv /velero/variables/gcp_credentials.json ~

sudo mv /grafana-agent-flow.yaml ~

sudo wget https://github.com/vmware-tanzu/velero/releases/download/v1.13.1/velero-v1.13.1-linux-arm64.tar.gz 

sudo tar -xvf velero-v1.13.1-linux-arm64.tar.gz 

sudo mv ./velero-v1.13.1-linux-arm64/velero /usr/local/bin 

velero install --provider gcp --bucket prometheus-velero --secret-file ./gcp_credentials.json --plugins velero/velero-plugin-for-gcp:v1.8.0 

helm install my-nginx bitnami/nginx --version 15.14.0 --create-namespace --namespace demo-0

helm install my-nginx bitnami/nginx --version 15.14.0 --create-namespace --namespace demo-1

velero backup create demo-0 --include-namespaces demo-0 

velero backup create demo-1 --include-namespaces demo-1 

kubectl delete ns demo-0 

kubectl delete ns demo-1

velero create restore --from-backup demo-0

velero create restore --from-backup demo-1

helm repo add grafana https://grafana.github.io/helm-charts

helm repo update

helm install grafana-agent-flow grafana/k8s-monitoring -n prometheus-velero --values grafana-agent-flow.yaml
