#!/bin/bash

set -e

echo "Installing K3s agent..."

# Wait for token file from server
while [ ! -f /vagrant/node-token ]; do
  echo "Waiting for server token..."
  sleep 5
done

K3S_TOKEN=$(cat /vagrant/node-token)
K3S_URL="https://192.168.56.110:6443"

# Install K3s in agent mode
curl -sfL https://get.k3s.io | K3S_URL=$K3S_URL K3S_TOKEN=$K3S_TOKEN sh -s - \
  --node-ip=192.168.56.111

echo "K3s agent installed successfully!"