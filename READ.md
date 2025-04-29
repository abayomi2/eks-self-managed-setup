# Installation of eks-setup.sh on master node run
# After successful run, copy and save the MASTER_IP, JOIN_TOKEN and DISCOVERY_HASH
# The script automatically initiate kubeadm on the master node
./eks-setup.sh master 

# Installation of eks-setup.sh on worker node run
./eks-setup.sh worker <MASTER_IP> <JOIN_TOKEN> <DISCOVERY_HASH>"
./eks-setup.sh worker 172.31.4.55 hd2xr0.4nzk3molev7ww1tb 75015788b8825f1adc32b6a75ee1b210acef9f3a85e03532e0575f4de64da27e

# you can deploy your application image directly by running 
kubectl create deployment abe --image abayomi2/abe-app:2.0
kubectl get deployment -o wide

# Expose the deployment
kubectl expose deployment abe --port 80
kubectl get service

# You can edit the deployment file to make changes such as the number of replica or images using
kubectl edit deployment abe

# To reapply the deployment after changes has been made to the deployment file
kubectl rollout restart deployment abe 

# You can edit the service file to make changes for NodePort or LoadBalancer
kubectl edit service abe  # Changes apply automatically

# Run this command to verify which of the node the application is deployed on 
# verify the node on which the pod is running on, get the public address and browse for your application on the port
kubectl get nodes
kubectl get pods -o wide 

# initiate the kubeadm on the control-plane server using the public-ip 
sudo kubeadm init --apiserver-advertise-address=44.223.108.34 --pod-network-cidr=192.168.0.0/16

# check all the container in the runtime endpoint
sudo crictl --runtime-endpoint unix:///var/run/containerd/containerd.sock ps -a | grep kube | grep -v pause

# show your IP address 
ip addr show

# Intitialize kubeadm on control-plane
sudo kubeadm init --control-plane-endpoint="172.31.8.255:6443" --upload-certs --apiserver-advertise-address=172.31.8.255 --pod-network-cidr=192.168.0.0/16

# To start using your cluster, run the following on master node as a regular user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

<!-- Use HTTPS via Ingress with TLS
If you want to expose your app over HTTPS, you need to:

Set up an Ingress Controller (like NGINX or AWS ALB Ingress).

Create a TLS secret with your SSL certificate and private key.

Create an Ingress resource that references the TLS secret and routes traffic to your Service. -->