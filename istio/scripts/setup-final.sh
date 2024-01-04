#!/bin/sh
    
sudo snap install kubectl --classic

curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-arm64
sudo install minikube-linux-arm64 /usr/local/bin/minikube
minikube start --memory=12000 --cpus=4

minikube addons enable metallb
export CIDR_BASE_ADDR="$(minikube ip)"
export FIRST_ADDR="$(echo "${CIDR_BASE_ADDR}" | awk -F'.' '{print $1,$2,$3,2}' OFS='.')"
export LAST_ADDR="$(echo "${CIDR_BASE_ADDR}" | awk -F'.' '{print $1,$2,$3,255}' OFS='.')"
kubectl get configmap -n metallb-system config -o yaml >> metallbconfig.yaml
sed -i -e "s/- -/- $FIRST_ADDR-$LAST_ADDR/g" metallbconfig.yaml
kubectl delete -f metallbconfig.yaml
kubectl apply -f metallbconfig.yaml

sudo snap install helm --classic

helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
kubectl create namespace istio-system
helm install istio-base istio/base -n istio-system --set defaultRevision=default --wait
helm install istiod istio/istiod -n istio-system --wait
kubectl create namespace istio-ingress
helm install istio-ingress istio/gateway -n istio-ingress --wait

kubectl label namespace default istio-injection=enabled
kubectl apply -f /istio/bookinfo/bookinfo.yaml
kubectl apply -f /istio/bookinfo/bookinfo-gateway.yaml
kubectl apply -f /istio/bookinfo/destination-rule-all.yaml
