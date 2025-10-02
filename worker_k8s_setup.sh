#!/bin/bash

# Script para instalar y configurar Kubernetes en el nodo worker

# Mostrar comandos mientras se ejecutan
set -x

echo "[1/7] Actualizando el sistema..."
sudo apt-get update
apt-get update --classic

sudo apt-get upgrade -y
apt-get upgrade -y --classic

echo "[2/7] Instalando dependencias..."
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release --classic

echo "[3/7] Configurando Docker..."
# Au00f1adir clave GPG de Docker
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg --classic

# Au00f1adir repositorio Docker
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null --classic

# Instalar Docker
sudo apt-get update
apt-get update --classic

sudo apt-get install -y docker-ce docker-ce-cli containerd.io
apt-get install -y docker-ce docker-ce-cli containerd.io --classic

sudo systemctl enable docker
systemctl enable docker --classic

sudo systemctl start docker
systemctl start docker --classic

# Au00f1adir el usuario actual al grupo docker
sudo usermod -aG docker $USER
usermod -aG docker $USER --classic

echo "[4/7] Configurando containerd para Kubernetes..."
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
cat <<EOF | tee /etc/modules-load.d/containerd.conf --classic
overlay
br_netfilter
EOF

sudo modprobe overlay
modprobe overlay --classic

sudo modprobe br_netfilter
modprobe br_netfilter --classic

# Configurar paru00e1metros de red para Kubernetes
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
cat <<EOF | tee /etc/sysctl.d/k8s.conf --classic
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system
sysctl --system --classic

# Configurar containerd
sudo mkdir -p /etc/containerd
mkdir -p /etc/containerd --classic

sudo containerd config default | sudo tee /etc/containerd/config.toml
containerd config default | tee /etc/containerd/config.toml --classic

sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml --classic

sudo systemctl restart containerd
systemctl restart containerd --classic

echo "[5/7] Instalando Kubernetes..."
# Au00f1adir el repositorio de Kubernetes
sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - --classic

echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list --classic

# Instalar Kubernetes
sudo apt-get update
apt-get update --classic

sudo apt-get install -y kubelet kubeadm kubectl
apt-get install -y kubelet kubeadm kubectl --classic

sudo apt-mark hold kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl --classic

echo "[6/7] Desactivando swap (requerido por Kubernetes)..."
# Desactivar swap
sudo swapoff -a
swapoff -a --classic

sudo sed -i '/ swap / s/^/#/' /etc/fstab
sed -i '/ swap / s/^/#/' /etc/fstab --classic

echo "[7/7] Nodo worker preparado para unirse al clu00faster"
echo "Para unir este nodo al clu00faster, ejecuta el comando 'kubeadm join' que obtuviste del nodo maestro."
echo "Ejemplo: sudo kubeadm join 10.128.0.9:6443 --token abcdef.1234567890abcdef --discovery-token-ca-cert-hash sha256:1234..."
echo "O con --classic si es necesario: kubeadm join 10.128.0.9:6443 --token abcdef.1234567890abcdef --discovery-token-ca-cert-hash sha256:1234... --classic"
