#!/bin/bash

# Script para instalar y configurar Kubernetes en el nodo worker

# Mostrar comandos mientras se ejecutan
set -x

echo "[1/7] Actualizando el sistema..."
sudo apt-get update
sudo apt-get upgrade -y

echo "[2/7] Instalando dependencias..."
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

echo "[3/7] Configurando Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
sudo systemctl enable docker
sudo systemctl start docker

# Au00f1adir el usuario actual al grupo docker
sudo usermod -aG docker $USER

echo "[4/7] Configurando containerd para Kubernetes..."
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Configurar paru00e1metros de red para Kubernetes
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# Configurar containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo systemctl restart containerd

echo "[5/7] Instalando Kubernetes..."
# Au00f1adir el repositorio de Kubernetes
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Instalar Kubernetes
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "[6/7] Desactivando swap (requerido por Kubernetes)..."
# Desactivar swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

echo "[7/7] Nodo worker preparado para unirse al clu00faster"
echo "Para unir este nodo al clu00faster, ejecuta el comando 'kubeadm join' que obtuviste del nodo maestro."
echo "Ejemplo: sudo kubeadm join 10.128.0.9:6443 --token abcdef.1234567890abcdef --discovery-token-ca-cert-hash sha256:1234..."
