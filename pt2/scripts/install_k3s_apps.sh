# #!/bin/bash

# # Install K3s
# echo "Installing K3s..."
# curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=traefik" sh -

# # Wait for K3s to initialize
# echo "Waiting for K3s to start..."
# sleep 30

# # Set up kubectl access for vagrant user
# echo "Setting up kubectl access..."
# mkdir -p /home/vagrant/.kube
# sudo cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
# sudo chown vagrant:vagrant /home/vagrant/.kube/config
# sudo chmod 600 /home/vagrant/.kube/config
# echo "export KUBECONFIG=/home/vagrant/.kube/config" >> /home/vagrant/.bashrc
# export KUBECONFIG=/home/vagrant/.kube/config

# # Install NGINX Ingress Controller
# echo "Installing NGINX Ingress Controller..."
# kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.1.1/deploy/static/provider/cloud/deploy.yaml

# # Wait for the ingress controller to be ready
# echo "Waiting for NGINX Ingress Controller to be ready..."
# sleep 60

# # Apply all the Kubernetes manifests from existing files
# echo "Applying Kubernetes manifests..."
# kubectl apply -f /vagrant/confs/app1-deployment.yaml
# kubectl apply -f /vagrant/confs/app2-deployment.yaml
# kubectl apply -f /vagrant/confs/app3-deployment.yaml
# kubectl apply -f /vagrant/confs/ingress.yaml

# # Add host entries for testing


# # Show pod status
# echo "Current pod status:"
# kubectl get pods -o wide

# # Get ingress address
# echo "Ingress status:"
# kubectl get ingress

# echo "Setup completed!"
# echo "You can access the applications at:"
# echo "- http://app1.com (First application)"
# echo "- http://app2.com (Second application with 3 replicas)"
# echo "- http://192.168.56.110 (Third application - default)"


echo "---------------------------------------------" 
echo "Hello World - $2 - Address $1" 
echo "---------------------------------------------" 

mkdir /home/vagrant/.kube


sudo curl -sfL https://get.k3s.io | \
    INSTALL_K3S_EXEC="server --node-ip $1 --bind-address=$1" \
    K3S_TOKEN=12345 \
    sh -s -
sudo echo 'alias k=kubectl' >> /home/vagrant/.bashrc
sudo echo 'export KUBECONFIG=/home/vagrant/.kube/config' >> /home/vagrant/.bashrc

sudo cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
sudo chmod 644 /home/vagrant/.kube/config

source ~/.bashrc
sudo kubectl apply -f /vagrant/confs/service.yaml
sudo kubectl apply -f /vagrant/confs/ingress.yaml
sudo kubectl apply -f /vagrant/confs/app1/deployment.yaml
sudo kubectl apply -f /vagrant/confs/app2/deployment.yaml
sudo kubectl apply -f /vagrant/confs/app3/deployment.yaml



# # # # Install k9s to explain only # # # #
sudo wget https://github.com/derailed/k9s/releases/download/v0.32.5/k9s_linux_amd64.deb
sudo apt install ./k9s_linux_amd64.deb
rm k9s_linux_amd64.deb

# k apply -f deployment.yaml