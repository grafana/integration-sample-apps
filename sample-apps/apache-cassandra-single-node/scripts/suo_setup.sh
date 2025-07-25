#!/bin/sh

# Re-set the KUBECONFIG since multipass exec does not load .profile or .bashrc correctly
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# JMX Exporter configuration - use environment variables if set, otherwise defaults
JMX_EXPORTER_VERSION="${JMX_EXPORTER_VERSION:-1.3.0}"
JMX_EXPORTER_PORT="${JMX_EXPORTER_PORT:-9145}"

echo "Using JMX Exporter Version: ${JMX_EXPORTER_VERSION}"
echo "Using JMX Exporter Port: ${JMX_EXPORTER_PORT}"

sudo apt-get update
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common qemu-user-static
sudo apt install docker.io -y

cd /home/ubuntu/configs

# Build with JMX exporter configuration so that we have a builtin jmx exporter within our image
sudo docker build \
  --build-arg JMX_EXPORTER_VERSION="${JMX_EXPORTER_VERSION}" \
  --build-arg JMX_EXPORTER_PORT="${JMX_EXPORTER_PORT}" \
  -t "sample/apache-cassandra:0.0.1" \
  .

sudo docker image save "sample/apache-cassandra:0.0.1" -o "apache-cassandra.tar"

# Import the tagged image into k3s
sudo k3s ctr -n=k8s.io images import "apache-cassandra.tar"

# Create namespace
kubectl create namespace cassandra --dry-run=client -o yaml | kubectl apply -f -

# Apply the deployment && service
kubectl apply -f /home/ubuntu/configs/deployment.yaml -n cassandra

# Apply the cronjob
kubectl apply -f /home/ubuntu/configs/cronjob.yaml -n cassandra

