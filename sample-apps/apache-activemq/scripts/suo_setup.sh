#!/bin/sh

# Re-set the KUBECONFIG since multipass exec does not load .profile or .bashrc correctly
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Install docker
sudo apt-get update && sudo apt-get install -y docker.io

cd /home/ubuntu/loadgen
sudo docker build -t sample/loadgenerator:0.0.1 .
sudo docker image save sample/loadgenerator:0.0.1 -o /home/ubuntu/loadgen/loadgenerator.tar

cd /home/ubuntu/configs
sudo docker build -t sample/apache-activemq:0.0.1 .
sudo docker image save sample/apache-activemq:0.0.1 -o /home/ubuntu/configs/apache-activemq.tar

sudo k3s ctr -n=k8s.io images import /home/ubuntu/loadgen/loadgenerator.tar
sudo k3s ctr -n=k8s.io images import /home/ubuntu/configs/apache-activemq.tar

sudo rm /home/ubuntu/loadgen/loadgenerator.tar
sudo rm /home/ubuntu/configs/apache-activemq.tar

kubectl create namespace apache-activemq --dry-run=client -o yaml | kubectl apply -f -
helm install apache-activemq . --namespace apache-activemq \
    --create-namespace \
    --values /home/ubuntu/configs/values.yaml \
    --wait
