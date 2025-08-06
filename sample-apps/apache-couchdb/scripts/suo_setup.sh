#!/bin/sh

# Re-set the KUBECONFIG since multipass exec does not load .profile or .bashrc correctly
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml


helm repo add couchdb https://apache.github.io/couchdb-helm
helm repo update

kubectl create namespace apache-couchdb --dry-run=client -o yaml | kubectl apply -f -

uuid=$(curl https://www.uuidgenerator.net/api/version4 2>/dev/null | tr -d -)

helm upgrade \
    apache-couchdb \
    couchdb/couchdb \
    --install \
    --namespace apache-couchdb \
    --create-namespace \
    --version 4.6.2 \
    --set allowAdminParty=true \
    --set couchdbConfig.couchdb.uuid=$uuid \
    --set couchdbConfig.couchdb.adminParty=true \
    --wait \
    --values /home/ubuntu/configs/values.yaml
    
