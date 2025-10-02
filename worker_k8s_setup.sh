#!/bin/bash

# Script para instalar y configurar Kubernetes en el nodo worker

# Mostrar comandos mientras se ejecutan
set -x

echo "[1/7] Actualizando el sistema..."
apt-get update --classic
apt-get upgrade -y --classic

echo "[2/7] Instalando dependencias..."
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release --classic

echo "[3/7] Configurando Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg --classic
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null --classic

# Instalar Docker
apt-get update --classic
apt-get install -y docker-ce docker-ce-cli containerd.io --classic
systemctl enable docker --classic
systemctl start docker --classic

# Au00f1adir el usuario actual al grupo docker
usermod -aG docker $USER --classic

echo "[4/7] Configurando containerd para Kubernetes..."
cat <<EOF | tee /etc/modules-load.d/containerd.conf --classic
overlay
br_netfilter
EOF

modprobe overlay --classic
modprobe br_netfilter --classic

# Configurar paru00e1metros de red para Kubernetes
cat <<EOF | tee /etc/sysctl.d/k8s.conf --classic
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system --classic

# Configurar containerd
mkdir -p /etc/containerd --classic
containerd config default | tee /etc/containerd/config.toml --classic
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml --classic
systemctl restart containerd --classic

echo "[5/7] Instalando Kubernetes..."
# Au00f1adir el repositorio de Kubernetes
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - --classic
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list --classic

# Instalar Kubernetes
apt-get update --classic
apt-get install -y kubelet kubeadm kubectl --classic
apt-mark hold kubelet kubeadm kubectl --classic

echo "[6/7] Desactivando swap (requerido por Kubernetes)..."
# Desactivar swap
swapoff -a --classic
sed -i '/ swap / s/^/#/' /etc/fstab --classic

echo "[7/7] Nodo worker preparado para unirse al clu00faster"
echo "Para unir este nodo al clu00faster, ejecuta el comando 'kubeadm join' que obtuviste del nodo maestro."
echo "Ejemplo: kubeadm join 10.128.0.9:6443 --token abcdef.1234567890abcdef --discovery-token-ca-cert-hash sha256:1234... --classic"
