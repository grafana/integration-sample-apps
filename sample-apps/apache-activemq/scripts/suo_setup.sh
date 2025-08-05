#!/bin/sh

# Re-set the KUBECONFIG since multipass exec does not load .profile or .bashrc correctly
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Install docker
sudo apt-get update && sudo apt-get install -y docker.io

cd /home/ubuntu/configs/loadgenerator
sudo docker build -t sample/loadgenerator:0.0.1 .
sudo docker image save sample/loadgenerator:0.0.1 -o /home/ubuntu/configs/loadgenerator/loadgenerator.tar

cd /home/ubuntu/configs
sudo docker build -t sample/activemq:0.0.1 .
sudo docker image save sample/activemq:0.0.1 -o /home/ubuntu/configs/activemq.tar

sudo k3s ctr -n=k8s.io images import /home/ubuntu/configs/loadgenerator/loadgenerator.tar
sudo k3s ctr -n=k8s.io images import /home/ubuntu/configs/activemq.tar

sudo rm /home/ubuntu/configs/loadgenerator/loadgenerator.tar
sudo rm /home/ubuntu/configs/activemq.tar


kubectl create namespace apache-activemq --dry-run=client -o yaml | kubectl apply -f -
helm install activemq . --namespace apache-activemq \
    --create-namespace \
    --values /home/ubuntu/configs/values.yaml \
    --wait
