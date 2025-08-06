#!/bin/sh

# Re-set the KUBECONFIG since multipass exec does not load .profile or .bashrc correctly
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

sudo apt-get update
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common qemu-user-static
sudo apt install -y docker.io

cd /home/ubuntu/configs
sudo docker build -t sample/influxdb-loadgen:0.0.1 .
sudo docker image save "sample/influxdb-loadgen:0.0.1" -o /home/ubuntu/configs/influxdb-loadgen.tar

sudo k3s ctr image import /home/ubuntu/configs/influxdb-loadgen.tar
sudo rm /home/ubuntu/configs/influxdb-loadgen.tar

helm repo add influxdata https://helm.influxdata.com/
kubectl create namespace influxdb --dry-run=client -o yaml | kubectl apply -f -

helm install influxdb influxdata/influxdb2 --namespace influxdb --create-namespace --wait --values /home/ubuntu/configs/values.yaml
kubectl apply -f /home/ubuntu/configs/loadgen.yaml
