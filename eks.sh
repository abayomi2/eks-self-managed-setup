#!/bin/bash

# Enhanced logging
echo "Starting the setup process for Kubernetes, Containerd, and Java..."

# Step 1: Update package information
echo "Updating package information..."
if ! sudo apt-get update; then
    echo "Error: Failed to update package information."
    exit 1
fi

# Step 2: Install prerequisite packages
echo "Installing prerequisite packages..."
if ! sudo apt-get install -y apt-transport-https ca-certificates curl gpg software-properties-common; then
    echo "Error: Failed to install prerequisite packages."
    exit 1
fi

# Step 3: Create /etc/apt/keyrings directory if it does not exist
echo "Creating /etc/apt/keyrings directory..."
if [ ! -d "/etc/apt/keyrings" ]; then
    if ! sudo mkdir -p -m 755 /etc/apt/keyrings; then
        echo "Error: Failed to create /etc/apt/keyrings directory."
        exit 1
    fi
fi

# Step 4: Download and store the Kubernetes GPG key
echo "Downloading Kubernetes GPG key..."
if ! curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg; then
    echo "Error: Failed to download Kubernetes GPG key."
    exit 1
fi

# Step 5: Add the Kubernetes repository
echo "Adding Kubernetes repository..."
if ! echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list; then
    echo "Error: Failed to add Kubernetes repository."
    exit 1
fi

# Step 6: Update package index
echo "Updating package index..."
if ! sudo apt-get update; then
    echo "Error: Failed to update package index."
    exit 1
fi

# Step 7: Install Kubernetes components
echo "Installing Kubernetes components (kubelet, kubeadm, kubectl)..."
if ! sudo apt-get install -y kubelet kubeadm kubectl; then
    echo "Error: Failed to install Kubernetes components."
    exit 1
fi

# Step 8: Prevent automatic upgrades for Kubernetes components
echo "Preventing automatic upgrades for Kubernetes components..."
if ! sudo apt-mark hold kubelet kubeadm kubectl; then
    echo "Error: Failed to hold Kubernetes components."
    exit 1
fi

# Step 9: Enable and start the kubelet service
echo "Enabling and starting kubelet service..."
if ! sudo systemctl enable --now kubelet; then
    echo "Error: Failed to enable and start kubelet service."
    exit 1
fi

# Step 10: Install containerd
echo "Installing containerd..."
if ! sudo apt-get install -y containerd; then
    echo "Error: Failed to install containerd."
    exit 1
fi

# Step 11: Configure containerd to use systemd cgroup driver
echo "Configuring containerd to use systemd cgroup driver..."
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Restart containerd
echo "Restarting containerd..."
if ! sudo systemctl restart containerd; then
    echo "Error: Failed to restart containerd."
    exit 1
fi

# Step 12: Pull the correct pause image
echo "Pulling correct pause image..."
if ! sudo ctr images pull registry.k8s.io/pause:3.10; then
    echo "Error: Failed to pull pause:3.10 image."
    exit 1
fi

# Step 13: Remove deprecated kubelet flags to allow kubelet to start cleanly
echo "Removing deprecated kubelet flags from /etc/default/kubelet..."
sudo tee /etc/default/kubelet <<EOF
# No extra args - avoid deprecated flags
EOF

# Reload systemd manager
echo "Reloading systemd manager..."
sudo systemctl daemon-reload

# Restart kubelet
echo "Restarting kubelet..."
if ! sudo systemctl restart kubelet; then
    echo "Error: Failed to restart kubelet."
    exit 1
fi

# Step 14: Install default Java (OpenJDK)
echo "Installing default Java (OpenJDK)..."
if ! sudo apt-get install -y default-jdk; then
    echo "Error: Failed to install Java."
    exit 1
fi

# Step 15: Set JAVA_HOME environment variable
echo "Configuring JAVA_HOME environment variable..."
JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:bin/java::")
echo "export JAVA_HOME=$JAVA_HOME" | sudo tee -a /etc/profile
echo "export PATH=\$JAVA_HOME/bin:\$PATH" | sudo tee -a /etc/profile
echo "export JAVA_HOME=$JAVA_HOME" | sudo tee -a /home/ubuntu/.profile
echo "export PATH=\$JAVA_HOME/bin:\$PATH" | sudo tee -a /home/ubuntu/.profile

echo "Applying environment variable changes immediately..."
source /etc/profile
source /home/ubuntu/.profile

# Step 16: Enable password authentication for SSH
echo "Enabling password authentication for SSH..."
if ! sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config; then
    echo "Error: Failed to enable password authentication in sshd_config."
    exit 1
fi
if ! sudo sed -i 's/^#\s*PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/ssh_config; then
    echo "Error: Failed to enable password authentication in ssh_config."
    exit 1
fi

# Step 17: Restart SSH service
echo "Restarting SSH service..."
if ! sudo systemctl restart ssh; then
    echo "Error: Failed to restart SSH service."
    exit 1
fi

# Final message
echo "Setup completed successfully! Kubernetes, Containerd, Java are installed, and SSH password authentication is enabled."




# RUN
sudo tee /etc/default/kubelet <<EOF
# No extra args - avoid deprecated flags
EOF

sudo systemctl daemon-reload
sudo systemctl restart kubelet
sudo systemctl status kubelet

# sudo reboot
kubeadm version
kubelet --version
kubectl version --client
containerd --version
systemctl start kubelet
systemctl start containerd
systemctl status kubelet
systemctl status containerd

update the script to Remove deprecated flags from /etc/default/kubelet To empty or no extra args,
sudo tee /etc/default/kubelet <<EOF
# No deprecated flags
EOF

sudo systemctl daemon-reload
sudo systemctl restart kubelet
sudo systemctl status kubelet


