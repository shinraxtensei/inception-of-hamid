#!/bin/bash

# Update system and install dependencies
apt-get update
apt-get install -y curl

# Wait for the server to be ready and the token to be available
while [ ! -f /vagrant/node-token ]; do
  echo "Waiting for server node token..."
  sleep 5
done

# Get the token
K3S_TOKEN=$(cat /vagrant/node-token)

# Install K3s in agent mode for ARM64
export INSTALL_K3S_ARCH=arm64
export INSTALL_K3S_EXEC="agent --server https://192.168.56.110:6443 --node-ip=192.168.56.111"
export K3S_TOKEN_FILE="/vagrant/node-token"
curl -sfL https://get.k3s.io | sh -

# # Set up password-less SSH
# if [ -f /vagrant/id_rsa.pub ]; then
#   mkdir -p /home/vagrant/.ssh
#   cat /vagrant/id_rsa.pub >> /home/vagrant/.ssh/authorized_keys
#   chown -R vagrant:vagrant /home/vagrant/.ssh
# fi

apt-get install -y net-tools
# Set up kubeconfig for agent
mkdir -p /home/vagrant/.kube
cp /vagrant/confs/k3s.yaml /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

echo "K3s agent installation completed for ARM64!"