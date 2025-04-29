#!/bin/bash

set -e

ROLE=$1  # "master" or "worker"
MASTER_IP=${2:-""}  # IP of the master (needed by worker)
JOIN_TOKEN=${3:-""}  # join token (needed by worker)
DISCOVERY_HASH=${4:-""}  # discovery CA hash (needed by worker)

if [[ -z "$ROLE" ]]; then
  echo "Usage:"
  echo "  For Master: sudo ./eks-setup.sh master"
  echo "  For Worker: sudo ./eks-setup.sh worker <MASTER_IP> <JOIN_TOKEN> <DISCOVERY_HASH>"
  exit 1
fi

echo "[Step 1] Updating server..."
sudo apt update && sudo apt upgrade -y

echo "[Step 2] Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "[Step 3] Configuring kernel modules and sysctl for Kubernetes..."
sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

echo "[Step 4] Installing Containerd runtime..."
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates

echo "[Step 5] Adding Docker repository..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y containerd.io

echo "[Step 6] Configuring containerd with systemd cgroup..."
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd

echo "[Step 7] Adding Kubernetes apt repository..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "[Step 8] Installing Java (optional)..."
sudo apt-get install -y default-jdk

JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:bin/java::")
echo "export JAVA_HOME=$JAVA_HOME" | sudo tee -a /etc/profile
echo "export PATH=\$JAVA_HOME/bin:\$PATH" | sudo tee -a /etc/profile

source /etc/profile

sudo systemctl start kubelet
sudo systemctl start containerd

# --- Based on role ---
if [[ "$ROLE" == "master" ]]; then
    echo "[Master Node] Initializing Kubernetes cluster..."
    sudo kubeadm init --pod-network-cidr=192.168.0.0/16

    echo "Setting up kubeconfig for the ubuntu user..."
    mkdir -p /home/ubuntu/.kube
    sudo cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
    sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config

    echo "Deploying Calico network plugin..."
    su - ubuntu -c "kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml"

    echo "Master node setup completed!"
elif [[ "$ROLE" == "worker" ]]; then
    if [[ -z "$MASTER_IP" || -z "$JOIN_TOKEN" || -z "$DISCOVERY_HASH" ]]; then
        echo "ERROR: Worker setup requires MASTER_IP, JOIN_TOKEN, and DISCOVERY_HASH."
        exit 1
    fi

    echo "[Worker Node] Joining Kubernetes cluster..."
    sudo kubeadm join $MASTER_IP:6443 --token $JOIN_TOKEN --discovery-token-ca-cert-hash sha256:$DISCOVERY_HASH

    echo "Worker node setup completed!"
else
    echo "Unknown role specified! Use 'master' or 'worker'."
    exit 1
fi

echo "Kubernetes setup finished successfully!"