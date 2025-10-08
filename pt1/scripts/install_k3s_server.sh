#!/bin/bash

set -e

echo "Installing K3s server..."

# Install K3s in server mode
curl -sfL https://get.k3s.io | sh -s - \
  --write-kubeconfig-mode 644 \
  --bind-address=192.168.56.110 \
  --node-ip=192.168.56.110

# Save token for worker node
sudo cat /var/lib/rancher/k3s/server/node-token > /vagrant/node-token

# Add alias for kubectl as 'k'
echo "alias k='kubectl'" >> ~/.bashrc

echo "K3s server installed successfully!"