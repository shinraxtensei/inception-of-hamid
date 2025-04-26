#!/bin/bash

# Simple setup script for K3d and Argo CD on macOS with different ports
set -e

echo "Installing required tools..."

# Install kubectl and k3d using brew
brew install kubectl k3d

# First, check which ports are available
echo "Checking for available ports..."
# Try different port combinations
PORT_HTTP=9080
PORT_APP=9888

echo "Creating K3d cluster with ports $PORT_HTTP and $PORT_APP..."
k3d cluster create iot-cluster --api-port 6443 --port "$PORT_HTTP:80@loadbalancer" --port "$PORT_APP:8888@loadbalancer" --agents 1

# Wait for cluster to be ready
sleep 10

# Install Argo CD
echo "Installing Argo CD..."
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Create dev namespace
kubectl create namespace dev

echo "Waiting for Argo CD to be ready..."
sleep 60  # Give it time to start up

# Get Argo CD password
echo "Argo CD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""

echo "Setup completed!"
echo "Access Argo CD UI: kubectl port-forward svc/argocd-server -n argocd 9090:443"
echo "HTTP services are available on port $PORT_HTTP"
echo "Application will be available on port $PORT_APP"


# admin
# gu4heJg7KEsDzqiU