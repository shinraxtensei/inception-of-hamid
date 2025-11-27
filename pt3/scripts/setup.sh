#!/bin/bash

# --- 1. PRE-REQUISITES & TOOLS ---

echo "=== Installing Docker ==="
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    echo "Docker installed. You may need to restart your session for group changes to take effect."
else
    echo "Docker is already installed."
fi

echo "=== Installing K3d ==="
wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

echo "=== Installing Kubectl ==="
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

echo "=== Setting up Aliases ==="
# Check if alias already exists to avoid duplication
if ! grep -q "alias k=kubectl" ~/.bashrc; then
    echo 'alias k=kubectl' >> ~/.bashrc
fi
source ~/.bashrc

# --- 2. CLUSTER CREATION ---

echo "=== Creating K3d Cluster ==="
# Port Mappings:
# 8080 -> 30000 (Argo CD Interface)
# 8888 -> 30001 (Your Application)
k3d cluster create mycluster --api-port 6550 \
    -p "8080:30000@server:0" \
    -p "8888:30001@server:0" \
    --wait

# --- 3. NAMESPACES ---

echo "=== Creating Namespaces ==="
# Creating namespaces as required by Part 3 [cite: 460]
kubectl create namespace argocd
kubectl create namespace dev

# --- 4. ARGOCD SETUP ---

echo "=== Installing Argo CD ==="
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "=== Patching Argo CD Service to NodePort 30000 ==="
# This exposes the Argo CD UI to your host on port 8080
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort", "ports": [{"name": "http", "port": 80, "targetPort": 8080, "nodePort": 30000}]}}'

# --- 5. APPLICATION DEPLOYMENT ---

echo "=== Applying Argo CD Application Config ==="
# This tells Argo CD to fetch your code from GitHub and deploy it to the 'dev' namespace [cite: 463]
if [ -f "../confs/app.yml" ]; then
    kubectl apply -f ../confs/app.yml
else
    echo "Error: ../confs/app.yml not found. Please check your file structure."
    exit 1
fi

echo "=== Waiting for Application Service to be created... ==="
while ! kubectl get svc playground-service -n dev &> /dev/null; do
    echo "Waiting for Argo CD to deploy playground-service..."
    sleep 5
done

echo "=== Patching Application Service to NodePort 30001 ==="
# This connects to the playground app (running on port 8888) to the host port 8888 via NodePort 30001
kubectl patch svc playground-service -n dev -p '{"spec": {"type": "NodePort", "ports": [{"port": 8888, "targetPort": 8888, "nodePort": 30001}]}}'

# --- 6. OUTPUT & CREDENTIALS ---

echo "=== Setup Complete ==="
echo "Argo CD URL: http://localhost:8080"
echo "Application URL: http://localhost:8888 (Wait for pods to be Ready)"
echo ""
echo "=== Argo CD Initial Admin Password ==="
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode; echo