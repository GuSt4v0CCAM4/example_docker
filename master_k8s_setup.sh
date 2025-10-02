#!/bin/bash

# Script para instalar y configurar Kubernetes en el nodo maestro

# Mostrar comandos mientras se ejecutan
set -x

echo "[1/10] Actualizando el sistema..."
sudo apt-get update
# Si aparece el mensaje de confirmación, ejecutar con --classic
apt-get update --classic

sudo apt-get upgrade -y
apt-get upgrade -y --classic

echo "[2/10] Instalando dependencias..."
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release --classic

echo "[3/10] Configurando Docker..."
# Añadir clave GPG de Docker
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg --classic

# Añadir repositorio Docker
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

# Añadir el usuario actual al grupo docker
sudo usermod -aG docker $USER
usermod -aG docker $USER --classic

echo "[4/10] Configurando containerd para Kubernetes..."
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

# Configurar parámetros de red para Kubernetes
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

echo "[5/10] Instalando Kubernetes..."
# Añadir el repositorio de Kubernetes
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

echo "[6/10] Desactivando swap (requerido por Kubernetes)..."
# Desactivar swap
sudo swapoff -a
swapoff -a --classic

sudo sed -i '/ swap / s/^/#/' /etc/fstab
sed -i '/ swap / s/^/#/' /etc/fstab --classic

echo "[7/10] Inicializando el clúster Kubernetes..."
# Iniciar el clúster Kubernetes
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$(hostname -I | awk '{print $1}')
kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$(hostname -I | awk '{print $1}') --classic

echo "[8/10] Configurando kubectl para el usuario normal..."
# Configurar kubectl para el usuario normal
mkdir -p $HOME/.kube

sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config --classic

sudo chown $(id -u):$(id -g) $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config --classic

echo "[9/10] Instalando red Flannel..."
# Instalar red Flannel para la comunicación entre pods
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

echo "[10/10] Configurando el clúster..."
# Permitir que el nodo maestro ejecute pods
kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule- || kubectl taint nodes --all node-role.kubernetes.io/master:NoSchedule-

# Etiquetar el nodo maestro para la base de datos
kubectl label node $(hostname) node-type=database

# Crear espacio de nombres para la aplicación
kubectl create namespace coarlumini

echo "Generando comando para unir nodos worker al clúster..."
# Generar comando para unir nodos worker
sudo kubeadm token create --print-join-command
JOIN_COMMAND=$(kubeadm token create --print-join-command --classic)

echo "Comando para unir nodo worker al clúster:"
echo $JOIN_COMMAND

echo "Verificando estado del clúster..."
kubectl get nodes

echo "¡Configuración del nodo maestro completada!"
echo "Para permitir que otros nodos se unan al clúster, ejecuta este comando en ellos:"
echo "$JOIN_COMMAND"
