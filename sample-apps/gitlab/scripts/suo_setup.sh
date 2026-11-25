#!/bin/sh
set -e

# Re-set the KUBECONFIG since multipass exec does not load .profile or .bashrc correctly
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Add GitLab Helm repository
helm repo add gitlab https://charts.gitlab.io/

# Update Helm repositories
helm repo update

kubectl create namespace gitlab || true

echo "Cleaning up any existing GitLab installation..."
helm uninstall gitlab -n gitlab 2>/dev/null || true

# Setup Gitaly PVC
kubectl delete -f /home/ubuntu/configs/gitaly-pvc.yaml 2>/dev/null || true
kubectl apply -f /home/ubuntu/configs/gitaly-pvc.yaml -n gitlab

kubectl delete secret gitlab-gitlab-initial-root-password -n gitlab 2>/dev/null || true

kubectl create secret generic gitlab-gitlab-initial-root-password --from-literal=password=$(head -c 512 /dev/urandom | LC_CTYPE=C tr -cd 'a-zA-Z0-9' | head -c 32)


helm upgrade --install gitlab gitlab/gitlab \
    --namespace gitlab \
    --values /home/ubuntu/configs/values.yaml \
    --version 9.1.2 \
    --timeout 20m

echo "Waiting for the GitLab webservice"
if ! kubectl rollout status deployment/gitlab-webservice-default -n gitlab --timeout=15m; then
    kubectl get pods -n gitlab -o wide || true
    kubectl top pods -n gitlab || true
    kubectl get events -n gitlab --sort-by=.lastTimestamp | tail -n 40 || true
    kubectl describe pods -n gitlab -l app=webservice || true
    kubectl logs -n gitlab -l app=webservice --all-containers --prefix --tail=50 || true
    kubectl logs -n gitlab -l app=migrations --all-containers --prefix --tail=50 || true
    exit 1
fi

kubectl apply -f /home/ubuntu/configs/load-generation.yaml
