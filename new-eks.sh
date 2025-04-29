#!/bin/bash

echo "update the server"
sudo apt update && sudo apt upgrade -y

# Disable Swap (all nodes)"
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Add Kernel Parameters (all nodes)
sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# Configure the critical kernel parameters for Kubernetes
sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# reload the changes
sudo sysctl --system

# Install Containerd Runtime (all nodes)
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates

# Enable the Docker repository
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Update the package list and install containerd
sudo apt update
sudo apt install -y containerd.io

# Configure containerd to start using systemd as cgroup
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

# Restart and enable the containerd service
sudo systemctl restart containerd
sudo systemctl enable containerd

# Add Apt Repository for Kubernetes (all nodes)
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Install Kubectl, Kubeadm, and Kubelet (all nodes)
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Step 13: Install default Java (OpenJDK)
sudo apt-get install -y default-jdk

# Step 14: Set JAVA_HOME environment variable
JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:bin/java::")
echo "export JAVA_HOME=$JAVA_HOME" | sudo tee -a /etc/profile
echo "export PATH=\$JAVA_HOME/bin:\$PATH" | sudo tee -a /etc/profile

JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:bin/java::")
echo "export JAVA_HOME=$JAVA_HOME" | sudo tee -a /home/ubuntu/.profile
echo "export PATH=\$JAVA_HOME/bin:\$PATH" | sudo tee -a /home/ubuntu/.profile

# Apply the environment variable changes immediately
source /etc/profile
source /home/ubuntu/.profile

# Step 15: Enable password authentication for SSH
sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i 's/^#\s*PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/ssh_config

# Step 16: Restart SSH service to apply changes
sudo systemctl restart ssh

# Verify kubeadm, kubectl, kubelet and containerd
kubeadm version
kubelet --version
kubectl version --client
containerd --version
systemctl start kubelet
systemctl start containerd
systemctl status kubelet
systemctl status containerd

# Final message
echo "Setup completed successfully! Kubernetes, Containerd, Java are installed, and SSH password authentication is enabled."

# Initialize Kubernetes Cluster with Kubeadm (master node)
