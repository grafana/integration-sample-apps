#!/bin/sh

# Re-set the KUBECONFIG since multipass exec does not load .profile or .bashrc correctly
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml


cd /home/ubuntu/configs

sudo apt-get update
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common qemu-user-static
sudo apt install docker.io -y

sudo docker build \
    -t sample/apache-mesos:0.0.1 \
    .

sudo docker image save "sample/apache-mesos:0.0.1" -o /home/ubuntu/configs/apache_mesos.tar

sudo k3s ctr image import /home/ubuntu/configs/apache_mesos.tar

sudo rm /home/ubuntu/configs/apache_mesos.tar

kubectl create namespace apache-mesos --dry-run=client -o yaml | kubectl apply -f -

helm upgrade \
    --install \
    apache-mesos-sample-app \
    . \
    -n apache-mesos \
    --create-namespace \
    --wait \
    --values /home/ubuntu/configs/values.yaml
