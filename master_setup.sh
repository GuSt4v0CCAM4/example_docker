#!/bin/bash
set -e

echo "[1/6] Actualizando el sistema..."
sudo apt-get update && sudo apt-get upgrade -y

echo "[2/6] Instalando dependencias..."
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

echo "[3/6] Configurando Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io
sudo usermod -aG docker $USER
sudo systemctl enable docker
sudo systemctl start docker

# Configuración de containerd para Kubernetes
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Configuración de red para Kubernetes
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system

# Configurar containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd

echo "[4/6] Instalando Kubernetes..."
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Deshabilitar swap
echo "[5/6] Deshabilitando swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Iniciar el clúster
echo "[6/6] Inicializando el clúster de Kubernetes..."
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Configurar kubectl para el usuario
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Instalar red Flannel
echo "Instalando red Flannel..."
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# Generar comando join
echo "Generando comando para unir nodos al clúster..."
JOIN_COMMAND=$(sudo kubeadm token create --print-join-command)
echo $JOIN_COMMAND > join_command.sh
chmod +x join_command.sh

echo "¡Clúster inicializado correctamente!"
echo "Ejecute el siguiente comando en los nodos worker para unirlos al clúster:"
echo $JOIN_COMMAND

# Crear espacio de nombres para Coarlumini
echo "Creando espacio de nombres para la aplicación..."
kubectl create namespace coarlumini

# Etiquetar el nodo maestro para que sea un nodo de trabajo
kubectl taint nodes --all node-role.kubernetes.io/master-
kubectl label node $(hostname) kubernetes.io/hostname=db-node
