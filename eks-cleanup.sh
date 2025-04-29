#!/bin/bash

set -e

echo "Starting full cleanup..."

# Stop services
echo "Stopping kubelet and containerd services..."
sudo systemctl stop kubelet || true
sudo systemctl stop containerd || true

# kubeadm reset
if command -v kubeadm &> /dev/null; then
    echo "Resetting Kubernetes cluster..."
    sudo kubeadm reset -f || true
fi

# Clean up CNI config
echo "Removing CNI network configuration..."
sudo rm -rf /etc/cni/net.d

# Flush iptables rules
echo "Flushing iptables rules..."
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t mangle -F
sudo iptables -X

# Reset IPVS if used
if command -v ipvsadm &> /dev/null; then
    echo "Clearing IPVS tables..."
    sudo ipvsadm --clear
fi

# Remove Kubernetes packages (handling held packages)
echo "Unholding and removing Kubernetes packages..."
sudo apt-mark unhold kubeadm kubectl kubelet || true
sudo apt purge -y kubelet kubeadm kubectl --allow-change-held-packages
sudo apt autoremove -y

# Remove containerd
echo "Removing containerd package..."
sudo apt purge -y containerd.io
sudo apt autoremove -y
sudo rm -rf /etc/containerd /var/lib/containerd

# Remove Docker and Kubernetes repositories and GPG keys
echo "Removing APT repositories and GPG keys..."
sudo rm -f /etc/apt/sources.list.d/docker.list
sudo rm -f /etc/apt/keyrings/docker.gpg
sudo rm -f /etc/apt/sources.list.d/kubernetes.list
sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Remove Java
echo "Removing Java..."
sudo apt purge -y default-jdk
sudo apt autoremove -y

# Remove JAVA_HOME settings
echo "Cleaning up JAVA_HOME environment variables..."
sudo sed -i '/JAVA_HOME/d' /etc/profile
sudo sed -i '/PATH=\$JAVA_HOME/d' /etc/profile
sudo sed -i '/JAVA_HOME/d' /home/ubuntu/.profile
sudo sed -i '/PATH=\$JAVA_HOME/d' /home/ubuntu/.profile

# Reload environment
source /etc/profile || true
source /home/ubuntu/.profile || true

# Restore Swap if disabled
echo "Restoring swap if disabled..."
sudo sed -i '/ swap / s/^#//g' /etc/fstab
sudo swapon --all || true

# Remove sysctl settings
echo "Removing Kubernetes sysctl config..."
sudo rm -f /etc/sysctl.d/kubernetes.conf
sudo sysctl --system

# Remove containerd module configs
sudo rm -f /etc/modules-load.d/containerd.conf

# Remove kube configs
echo "Removing .kube directory..."
sudo rm -rf ~/.kube /root/.kube

# Free Kubernetes ports
echo "Killing processes holding Kubernetes-related ports..."
for port in 6443 2379 2380 10250 10251 10252 10255 10257 10259 179; do
    pid=$(sudo lsof -t -i:$port || true)
    if [ -n "$pid" ]; then
        echo "Killing process on port $port (PID: $pid)..."
        sudo kill -9 $pid
    fi
done

# Reload systemd daemon
echo "Reloading systemd daemon..."
sudo systemctl daemon-reexec

# Final cleanup
echo "Final apt cleanup..."
sudo apt update
sudo apt autoremove -y
sudo apt autoclean -y

echo "✅ Cleanup completed successfully. Server is now fresh for reinstallation."
