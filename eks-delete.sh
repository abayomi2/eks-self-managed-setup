#!/bin/bash

echo "Stopping kubelet service if running..."
sudo systemctl stop kubelet || echo "kubelet not running"

echo "Stopping containerd service if running..."
sudo systemctl stop containerd || echo "containerd not running"

echo "Resetting kubeadm cluster state..."
sudo kubeadm reset -f

echo "Purging Kubernetes packages (kubeadm, kubelet, kubectl) including held packages..."
sudo apt-get purge --allow-change-held-packages -y kubeadm kubelet kubectl

echo "Purging containerd package if installed..."
sudo apt-get purge -y containerd || echo "containerd not installed"

echo "Autoremoving unused packages..."
sudo apt-get autoremove -y

echo "Removing Kubernetes and containerd related directories..."
sudo rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd ~/.kube /var/lib/containerd /etc/cni/net.d /opt/cni

echo "Flushing all iptables rules..."
sudo iptables -F
sudo iptables -X
sudo iptables -t nat -F
sudo iptables -t nat -X
sudo iptables -t mangle -F
sudo iptables -t mangle -X

echo "Disabling kubelet and containerd services..."
sudo systemctl disable kubelet || echo "kubelet service already disabled"
sudo systemctl disable containerd || echo "containerd service already disabled"

echo "Cleanup complete. System is ready for a fresh Kubernetes installation."




# To Reset kubeadm
sudo kubeadm reset --force

# Remove Kubernetes manifests
sudo rm -rf /etc/kubernetes/manifests
sudo rm -rf /etc/kubernetes/pki
sudo rm -rf /etc/cni/net.d
sudo rm -rf /.kube

# Restart containerd and kubelet (clean services)
sudo systemctl restart containerd
sudo systemctl restart kubelet

# Make sure swap is OFF (important for kubeadm init)
sudo swapoff -a
