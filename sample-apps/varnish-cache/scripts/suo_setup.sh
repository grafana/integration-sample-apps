#!/bin/sh

# Re-set the KUBECONFIG since multipass exec does not load .profile or .bashrc correctly
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

sudo apt-get update
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common qemu-user-static
sudo apt install docker.io -y


cd /home/ubuntu/configs

sudo docker build \
    --platform linux/amd64 \
    -t "sample/varnish:0.0.1" \
    .

sudo docker image save "sample/varnish:0.0.1" -o /home/ubuntu/configs/varnish.tar
sudo k3s ctr image import /home/ubuntu/configs/varnish.tar
# clean up to avoid helm trying to read this image
sudo rm /home/ubuntu/configs/varnish.tar
kubectl create namespace varnish --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install varnish-cache-sample-app . -n varnish --create-namespace --wait --values /home/ubuntu/configs/values.yaml
