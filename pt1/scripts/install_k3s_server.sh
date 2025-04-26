#!/bin/bash

# Update system and install dependencies
apt-get update
apt-get install -y curl

# Install K3s in server mode for ARM64
export INSTALL_K3S_ARCH=arm64
export INSTALL_K3S_EXEC="--bind-address=192.168.56.110 --node-ip=192.168.56.110"
curl -sfL https://get.k3s.io | sh -

# Wait for K3s to start up
sleep 10

# Copy the K3s token to a shared location for the agent to use
cp /var/lib/rancher/k3s/server/node-token /vagrant/node-token

# Copy the kubeconfig file to the shared location for easier access
mkdir -p /vagrant/confs
cp /etc/rancher/k3s/k3s.yaml /vagrant/confs/k3s.yaml
sed -i "s/127.0.0.1/192.168.56.110/g" /vagrant/confs/k3s.yaml

# Set up kubectl for the vagrant user
mkdir -p /home/vagrant/.kube
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
sed -i "s/127.0.0.1/192.168.56.110/g" /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube


apt-get install -y net-tools

# # Generate SSH key for password-less SSH
# if [ ! -f /home/vagrant/.ssh/id_rsa ]; then
#   sudo -u vagrant ssh-keygen -t rsa -N "" -f /home/vagrant/.ssh/id_rsa
#   cat /home/vagrant/.ssh/id_rsa.pub >> /home/vagrant/.ssh/authorized_keys
#   cp /home/vagrant/.ssh/id_rsa.pub /vagrant/id_rsa.pub
# fi

echo "K3s server installation completed for ARM64!"