
# #!/bin/bash
# # Update and install required packages
# sudo apt-get update
# sudo apt-get install -y apt-transport-https ca-certificates curl gnupg software-properties-common

# # Install kubectl
# curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
# sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
# echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
# sudo apt-get update
# sudo apt-get install -y kubectl

# # Install Docker
# curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
# sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
# sudo apt-get update
# sudo apt install -y docker-ce
# sudo usermod -aG docker $USER

# # Install k3d
# curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# # Delete existing cluster if it exists
# k3d cluster delete mycluster 2>/dev/null || true

# # Create a k3d cluster with proper port mappings
# k3d cluster create mycluster \
#   --api-port 6443 \
#   --servers 1 \
#   --agents 1 \
#   --port "80:80@loadbalancer" \
#   --port "443:443@loadbalancer" \
#   --port "8888:8888@loadbalancer" \
#   --wait

# # Wait for the cluster to be ready
# sleep 10

# # Create namespaces
# kubectl create namespace argocd
# kubectl create namespace dev

# # Install ArgoCD
# kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# # Wait for ArgoCD to be ready
# echo "Waiting for ArgoCD to be ready..."
# sleep 60

# # Patch ArgoCD server to use LoadBalancer for easier access
# kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# # Apply the ArgoCD application manifest
# kubectl apply -f ./confs/application.yaml

# # Get the initial admin password
# echo "========================================"
# echo "Fetching ArgoCD admin password:"
# kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
# echo "========================================"
# echo "ArgoCD should now be accessible at:"
# echo "http://localhost (for HTTP) or https://localhost (for HTTPS)"
# echo "Username: admin"
# echo "Password: (displayed above)"
# echo "========================================"
# echo "Your application should be accessible at:"
# echo "http://localhost:8888"
# echo "kubectl port-forward svc/argocd-server -n argocd 8080:443 --address='0.0.0.0'"
# echo "========================================"

# # Display pod and service status
# echo "ArgoCD Pods:"
# kubectl get pods -n argocd
# echo "Dev Pods:"
# kubectl get pods -n dev
# echo "All Services:"
# kubectl get svc -A


#!/bin/bash
# Update and install required packages
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg software-properties-common

# Install kubectl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubectl

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
sudo apt-get update
sudo apt install -y docker-ce
sudo usermod -aG docker $USER

# Install k3d
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Delete existing cluster if it exists
k3d cluster delete mycluster 2>/dev/null || true

# Create a k3d cluster with explicit port mappings
k3d cluster create mycluster \
  --api-port 6443 \
  --servers 1 \
  --agents 1 \
  --port "8080:30080@server:0" \
  --port "8888:30888@server:0" \
  --wait

# Create namespaces
kubectl create namespace argocd
kubectl create namespace dev

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
echo "Waiting for ArgoCD to be ready..."
sleep 30

# Configure ArgoCD to use HTTP mode
kubectl patch configmap argocd-cmd-params-cm -n argocd -p '{"data":{"server.insecure":"true"}}'

# Set shorter sync period for quicker updates
kubectl patch configmap argocd-cm -n argocd --type=merge -p '{"data":{"timeout.reconciliation":"5s"}}'

# Expose ArgoCD with NodePort service
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort", "ports": [{"name": "http", "port": 80, "targetPort": 8080, "nodePort": 30080}]}}'

# Restart ArgoCD to apply changes
kubectl rollout restart deployment argocd-server -n argocd
sleep 15

# Apply the Application manifest
kubectl apply -f ./confs/application.yaml

# Wait for application to be created
echo "Waiting for application to be deployed..."
sleep 20

# Configure application service as NodePort
kubectl patch svc playground-service -n dev -p '{"spec": {"type": "NodePort", "ports": [{"port": 8888, "targetPort": 8888, "nodePort": 30888}]}}' || echo "Service not found yet, will try again"
sleep 10
kubectl patch svc playground-service -n dev -p '{"spec": {"type": "NodePort", "ports": [{"port": 8888, "targetPort": 8888, "nodePort": 30888}]}}' || echo "Service still not found"

# Get the initial admin password
echo "========================================"
echo "Fetching ArgoCD admin password:"
ARGO_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "$ARGO_PWD"
echo "========================================"
echo "ArgoCD should be accessible at: http://localhost:8080"
echo "Username: admin"
echo "Password: $ARGO_PWD"
echo "========================================"
echo "Your application should be accessible at: http://localhost:8888"
echo "========================================"

# Show cluster status
kubectl get pods,svc -n argocd
kubectl get pods,svc -n dev