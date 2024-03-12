#!/bin/sh
    
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
minikube start --memory=12000 --cpus=4 --kubernetes-version=v1.23.17 # Last version that fully supported docker
GATEWAY_IP="$(ip r | grep default | cut -d' ' -f3) grafana.k3d.localhost loki.k3d.localhost mimir.k3d.localhost"
echo "$GATEWAY_IP" | sudo tee -a /etc/hosts

# Setup metallb for Istio's gateway to work
minikube addons enable metallb
export CIDR_BASE_ADDR="$(minikube ip)"
export FIRST_ADDR="$(echo "${CIDR_BASE_ADDR}" | awk -F'.' '{print $1,$2,$3,2}' OFS='.')"
export LAST_ADDR="$(echo "${CIDR_BASE_ADDR}" | awk -F'.' '{print $1,$2,$3,255}' OFS='.')"
kubectl get configmap -n metallb-system config -o yaml >> metallbconfig.yaml
sed -i -e "s/- -/- $FIRST_ADDR-$LAST_ADDR/g" metallbconfig.yaml
kubectl delete -f metallbconfig.yaml
kubectl apply -f metallbconfig.yaml

sudo snap install helm --classic

# Install Istio
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
kubectl create namespace istio-system
helm install istio-base istio/base -n istio-system --set defaultRevision=default --wait
helm install istiod istio/istiod -n istio-system --set meshConfig.accessLogFile=/dev/stdout --wait
kubectl create namespace istio-ingress
helm install istio-ingress istio/gateway -n istio-ingress --wait

# Install bookinfo sample app for Istio
kubectl label namespace default istio-injection=enabled
kubectl apply -f /istio/bookinfo/bookinfo.yaml
kubectl apply -f /istio/bookinfo/bookinfo-gateway.yaml
kubectl apply -f /istio/bookinfo/destination-rule-all.yaml

# Install Grafana Agent Flow
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Using user input, create values.yaml (for Grafana Agent Flow helm) from template
sudo snap install yq
sudo apt-get install libregexp-common-perl
cp /istio/resources/values-template.yaml ./values.yaml
cp /istio/resources/user-inputs.yaml ./user-inputs.yaml
PROM_URL=$(yq eval '.prom_url' user-inputs.yaml)
PROM_USER=$(yq eval '.prom_user' user-inputs.yaml)
PROM_PASS=$(yq eval '.prom_pass' user-inputs.yaml)
LOKI_URL=$(yq eval '.loki_url' user-inputs.yaml)
LOKI_USER=$(yq eval '.loki_user' user-inputs.yaml)
LOKI_PASS=$(yq eval '.loki_pass' user-inputs.yaml)
ESC_PROM_URL=$(perl -MRegexp::Common -le "print quotemeta q($PROM_URL)")
ESC_PROM_USER=$(perl -MRegexp::Common -le "print quotemeta q($PROM_USER)")
ESC_PROM_PASS=$(perl -MRegexp::Common -le "print quotemeta q($PROM_PASS)")
ESC_LOKI_URL=$(perl -MRegexp::Common -le "print quotemeta q($LOKI_URL)")
ESC_LOKI_USER=$(perl -MRegexp::Common -le "print quotemeta q($LOKI_USER)")
ESC_LOKI_PASS=$(perl -MRegexp::Common -le "print quotemeta q($LOKI_PASS)")
sed -i -e "s/\$PROM_URL/$ESC_PROM_URL/g" values.yaml
sed -i -e "s/\$PROM_USER/$ESC_PROM_USER/g" values.yaml
sed -i -e "s/\$PROM_PASS/$ESC_PROM_PASS/g" values.yaml
sed -i -e "s/\$LOKI_URL/$ESC_LOKI_URL/g" values.yaml
sed -i -e "s/\$LOKI_USER/$ESC_LOKI_USER/g" values.yaml
sed -i -e "s/\$LOKI_PASS/$ESC_LOKI_PASS/g" values.yaml

helm install grafana-agent-flow grafana/k8s-monitoring -n istio-system --values values.yaml
