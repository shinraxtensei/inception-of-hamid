#!/bin/bash

set -e

echo "Installing K3s server..."

# Install K3s in server mode
curl -sfL https://get.k3s.io | sh -s - \
  --write-kubeconfig-mode 644 \
  --bind-address=192.168.56.110 \
  --node-ip=192.168.56.110

# Wait for K3s to be ready
until sudo kubectl get nodes 2>/dev/null; do
  echo "Waiting for K3s to start..."
  sleep 5
done

# Save token for worker node
sudo cat /var/lib/rancher/k3s/server/node-token > /vagrant/node-token

echo "K3s server installed successfully!"