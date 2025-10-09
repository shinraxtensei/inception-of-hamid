#!/bin/bash

set -e

echo "=== Cleaning up ==="
sudo rm -f /etc/apt/sources.list.d/helm-stable-debian.list
sudo rm -f /usr/share/keyrings/helm.gpg

echo "=== Installing required packages ==="
sudo apt-get update
sudo apt-get install -y curl wget ca-certificates

echo "=== Installing Docker ==="
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

echo "=== Installing kubectl ==="
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

echo "=== Installing Helm ==="
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "=== Installing k3d ==="
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

echo "=== Creating k3d cluster ==="
k3d cluster delete mycluster
k3d cluster create mycluster \
  --api-port 6550 \
  -p "0.0.0.0:8080:80@loadbalancer" \
  -p "0.0.0.0:8090:8090@loadbalancer" \
  -p "0.0.0.0:8888:8888@loadbalancer" \
  --wait


echo "=== Creating namespaces ==="
kubectl create namespace gitlab
kubectl create namespace argocd
kubectl create namespace dev

echo "=== Installing GitLab ==="
helm repo add gitlab https://charts.gitlab.io/
helm repo update

helm install gitlab gitlab/gitlab \
  --namespace gitlab \
  --timeout 20m \
  --set global.hosts.domain=example.com \
  --set global.edition=ce \
  --set nginx-ingress.enabled=false \
  --set prometheus.install=false \
  --set gitlab-runner.install=false \
  --set global.ingress.enabled=false \
  --set certmanager-issuer.enabled=false \
  --set certmanager-issuer.email=darkhamiid@gmail.com


echo "=== Installing ArgoCD ==="
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "=== Waiting for ArgoCD to be ready ==="
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

echo "=== Configuring ArgoCD for insecure mode ==="
kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data":{"server.insecure":"true"}}'

echo "=== Exposing ArgoCD ==="
kubectl patch svc argocd-server -n argocd --type merge -p '{"spec":{"type":"LoadBalancer","ports":[{"name":"http","port":8080,"targetPort":8080,"protocol":"TCP"}]}}'

echo "=== Restarting ArgoCD server ==="
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout status deployment argocd-server -n argocd

echo "=== Waiting for GitLab (this may take a while) ==="
kubectl wait --for=condition=ready pod -l app=webservice -n gitlab --timeout=1800s || true

echo "=== Exposing GitLab ==="
kubectl patch svc gitlab-webservice-default -n gitlab --type merge -p '{"spec":{"type":"LoadBalancer","ports":[{"name":"http","port":8090,"targetPort":8181,"protocol":"TCP"}]}}'

echo "=== Deploying Application ==="
kubectl apply -f ./confs/application.yaml

echo "=== Waiting for application sync ==="
sleep 30

echo "========================================"
echo "ArgoCD Password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""
echo "GitLab Password:"
kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -o jsonpath="{.data.password}" | base64 -d
echo ""
echo "========================================"
echo "ArgoCD UI: http://104.248.23.108:8080"
echo "Username: admin"
echo ""
echo "GitLab UI: http://104.248.23.108:8090"
echo "Username: root"
echo ""
echo "App URL: http://104.248.23.108:8888"
echo "========================================"

kubectl get all -n gitlab
kubectl get all -n argocd
kubectl get all -n dev