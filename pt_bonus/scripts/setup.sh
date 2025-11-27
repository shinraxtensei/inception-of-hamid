#!/bin/bash

set -e  # Exit on error

# --- 1. PRE-REQUISITES ---

echo "=== Checking Prerequisites ==="
command -v docker >/dev/null || { curl -fsSL https://get.docker.com | sh; sudo usermod -aG docker $USER; }
command -v k3d >/dev/null || wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
command -v kubectl >/dev/null || {
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
}
command -v helm >/dev/null || curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# --- 2. CLUSTER ---

echo "=== Creating K3d Cluster ==="
k3d cluster delete mycluster 2>/dev/null || true
k3d cluster create mycluster --api-port 6550 \
    -p "8080:30000@server:0" \
    -p "8888:30001@server:0" \
    -p "8081:30002@server:0" \
    --wait

# --- 3. NAMESPACES ---

echo "=== Creating Namespaces ==="
kubectl create namespace argocd
kubectl create namespace dev
kubectl create namespace gitlab

# --- 4. ARGOCD ---

echo "=== Installing Argo CD ==="
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
sleep 30
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort", "ports": [{"name": "http", "port": 80, "targetPort": 8080, "nodePort": 30000}]}}'

# --- 5. GITLAB ---

echo "=== Installing GitLab (15-20 minutes) ==="
helm repo add gitlab https://charts.gitlab.io/ 2>/dev/null || true
helm repo update
helm install gitlab gitlab/gitlab \
  --namespace gitlab \
  --timeout 25m \
  --set global.edition=ce \
  --set global.hosts.domain=gitlab.local \
  --set global.hosts.https=false \
  --set global.ingress.enabled=false \
  --set global.ingress.configureCertmanager=false \
  --set certmanager.enabled=false \
  --set nginx-ingress.enabled=false \
  --set prometheus.install=false \
  --set gitlab-runner.install=false \
  --set registry.enabled=false \
  --set gitlab.webservice.service.type=NodePort \
  --set gitlab.webservice.service.workhorse.nodePort=30002 \
  --set gitlab.webservice.minReplicas=1 \
  --set gitlab.webservice.maxReplicas=1 \
  --set gitlab.gitlab-shell.minReplicas=1 \
  --set gitlab.gitlab-shell.maxReplicas=1 \
  --set gitlab.kas.minReplicas=1 \
  --set gitlab.kas.maxReplicas=1

kubectl wait --for=condition=ready pod -l app=webservice -n gitlab --timeout=25m 2>/dev/null || echo "Still deploying..."

echo "=== Patching GitLab Service ==="
kubectl patch svc gitlab-webservice-default -n gitlab --patch "$(cat <<EOF
spec:
  type: NodePort
  ports:
  - name: http-workhorse
    port: 8181
    targetPort: 8181
    nodePort: 30002
    protocol: TCP
  - name: http-metrics
    port: 8083
    targetPort: 8083
    protocol: TCP
EOF
)"

# --- 6. OUTPUT ---

echo ""
echo "============================================"
echo "=== Setup Complete ==="
echo "============================================"
echo ""
echo " URLs:"
echo "   ArgoCD:  http://$(curl -s ifconfig.me):8080"
echo "   GitLab:  http://$(curl -s ifconfig.me):8081"
echo "   App:     http://$(curl -s ifconfig.me):8888"
echo ""
echo " Credentials:"
echo "   ArgoCD: admin / $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 --decode || echo 'pending')"
echo "   GitLab: root / $(kubectl -n gitlab get secret gitlab-gitlab-initial-root-password -o jsonpath='{.data.password}' 2>/dev/null | base64 --decode || echo 'pending')"
echo ""