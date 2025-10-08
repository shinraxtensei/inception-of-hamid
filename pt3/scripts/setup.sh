#!/bin/bash

set -e

echo "=== Installing required packages ==="
sudo apt-get update
sudo apt-get install -y curl

echo "=== Installing Docker ==="
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

echo "=== Installing kubectl ==="
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

echo "=== Installing k3d ==="
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

echo "=== Creating k3d cluster ==="
k3d cluster delete mycluster 2>/dev/null || true
k3d cluster create mycluster \
  --port "8080:80@loadbalancer" \
  --port "8888:8888@loadbalancer"

echo "=== Creating namespaces ==="
kubectl create namespace argocd
kubectl create namespace dev

echo "=== Installing ArgoCD ==="
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "=== Waiting for ArgoCD to be ready ==="
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

echo "=== Exposing ArgoCD ==="
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

echo "=== Deploying Application ==="
kubectl apply -f /vagrant/confs/application.yaml

echo "=== Waiting for application sync ==="
sleep 30

echo "========================================"
echo "ArgoCD Password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""
echo "========================================"
echo "ArgoCD UI: http://localhost:8080"
echo "Username: admin"
echo "App URL: http://localhost:8888"
echo "========================================"

kubectl get all -n argocd
kubectl get all -n dev