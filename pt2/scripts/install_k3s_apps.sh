#!/bin/bash

set -e

echo "Installing K3s server with applications..."

# Install K3s
curl -sfL https://get.k3s.io | sh -s - \
  --write-kubeconfig-mode 644 \
  --node-ip 192.168.56.110 \
  --bind-address=192.168.56.110

# Wait for K3s to be ready
until kubectl get nodes 2>/dev/null; do
  echo "Waiting for K3s..."
  sleep 5
done

# Setup kubectl alias for vagrant user
echo 'alias k=kubectl' >> /home/vagrant/.bashrc

# Deploy applications
kubectl apply -f /vagrant/confs/app1-deployment.yaml
kubectl apply -f /vagrant/confs/app2-deployment.yaml
kubectl apply -f /vagrant/confs/app3-deployment.yaml
kubectl apply -f /vagrant/confs/ingress.yaml

echo "K3s server with apps installed successfully!"
echo "Access apps via:"
echo "  curl -H 'Host: app1.com' 192.168.56.110"
echo "  curl -H 'Host: app2.com' 192.168.56.110"
echo "  curl -H 'Host: app3.com' 192.168.56.110"