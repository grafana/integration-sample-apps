#!/bin/sh

# Re-set the KUBECONFIG since multipass exec does not load .profile or .bashrc correctly
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Install Grafana helm repo
helm repo add grafana https://grafana.github.io/helm-charts

# Based on https://github.com/confluentinc/confluent-kubernetes-examples/tree/master/quickstart-deploy
git clone https://github.com/confluentinc/confluent-kubernetes-examples.git

# Set CRD location
export QUICKSTART_HOME="/home/ubuntu/confluent-kubernetes-examples/quickstart-deploy"

# Create namespace
kubectl create namespace confluent

# Add helm chart
helm repo add confluentinc https://packages.confluent.io/helm
helm repo update

helm upgrade --install confluent-operator confluentinc/confluent-for-kubernetes --namespace confluent

# Kafka components
kubectl apply -f $QUICKSTART_HOME/confluent-platform.yaml

# Give the components a chance to get started
sleep 1m 30s

# producer app and topic
kubectl apply -f $QUICKSTART_HOME/producer-app-data.yaml
