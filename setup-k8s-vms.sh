#!/bin/bash

# Script para configurar dos VMs de Google Cloud para un clúster Kubernetes
# Una VM será el nodo maestro y la otra será un nodo worker.
# El clúster tendrá 3 nodos en total para ejecutar backend, frontend y base de datos.

# Colores para la salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir mensajes con colores
print_info() {
    echo -e "${BLUE}INFO: $1${NC}"
}

print_success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

print_error() {
    echo -e "${RED}ERROR: $1${NC}"
}

# Configuración
PROJECT_ID="cloudcomputingunsa"
ZONE="us-central1-a"
MASTER_NAME="coarlumini-master"
WORKER_NAME="coarlumini-worker"
MACHINE_TYPE="e2-small" # 2 vCPUs, 2GB RAM
DISK_SIZE="50GB"
DISK_TYPE="pd-standard"

# Configurar proyecto
print_info "Configurando proyecto: $PROJECT_ID en zona $ZONE"
gcloud config set project $PROJECT_ID
gcloud config set compute/zone $ZONE

# Habilitar APIs necesarias
print_info "Habilitando APIs necesarias..."
gcloud services enable compute.googleapis.com

# Crear VM para el nodo maestro
print_info "Creando VM para el nodo maestro: $MASTER_NAME..."
gcloud compute instances create $MASTER_NAME \
  --zone=$ZONE \
  --machine-type=$MACHINE_TYPE \
  --subnet=default \
  --network-tier=PREMIUM \
  --maintenance-policy=MIGRATE \
  --image=ubuntu-2004-focal-v20230213 \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=$DISK_SIZE \
  --boot-disk-type=$DISK_TYPE \
  --boot-disk-device-name=$MASTER_NAME \
  --tags=k8s-master,http-server,https-server \
  --scopes=https://www.googleapis.com/auth/cloud-platform

# Crear VM para el nodo worker
print_info "Creando VM para el nodo worker: $WORKER_NAME..."
gcloud compute instances create $WORKER_NAME \
  --zone=$ZONE \
  --machine-type=$MACHINE_TYPE \
  --subnet=default \
  --network-tier=PREMIUM \
  --maintenance-policy=MIGRATE \
  --image=ubuntu-2004-focal-v20230213 \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=$DISK_SIZE \
  --boot-disk-type=$DISK_TYPE \
  --boot-disk-device-name=$WORKER_NAME \
  --tags=k8s-worker,http-server,https-server \
  --scopes=https://www.googleapis.com/auth/cloud-platform

# Esperar a que las VMs estén listas
print_info "Esperando a que las VMs estén listas..."
sleep 30

# Crear script para inicializar el nodo maestro
cat > master_setup.sh << 'EOL'
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
EOL

# Crear script para inicializar el nodo worker
cat > worker_setup.sh << 'EOL'
#!/bin/bash
set -e

echo "[1/4] Actualizando el sistema..."
sudo apt-get update && sudo apt-get upgrade -y

echo "[2/4] Instalando dependencias..."
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

echo "[3/4] Configurando Docker..."
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

echo "[4/4] Instalando Kubernetes..."
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Deshabilitar swap
echo "Deshabilitando swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

echo "Nodo worker preparado."
echo "Una vez que el nodo maestro esté inicializado, ejecute el comando join proporcionado por el nodo maestro."
EOL

# Crear script para etiquetar nodos
cat > label_nodes.sh << 'EOL'
#!/bin/bash

# Etiquetar el segundo nodo como nodo de backend
kubectl label node $(kubectl get nodes | grep -v master | grep Ready | head -1 | awk '{print $1}') kubernetes.io/hostname=backend-node

# Etiquetar el tercer nodo como nodo de frontend
kubectl label node $(kubectl get nodes | grep -v master | grep Ready | tail -1 | awk '{print $1}') kubernetes.io/hostname=frontend-node

# Verificar las etiquetas
echo "Nodos etiquetados:"
kubectl get nodes --show-labels
EOL

# Copiar scripts a las VMs
print_info "Copiando scripts a las VMs..."
gcloud compute scp master_setup.sh $MASTER_NAME:~/ --zone=$ZONE
gcloud compute scp worker_setup.sh $WORKER_NAME:~/ --zone=$ZONE
gcloud compute scp label_nodes.sh $MASTER_NAME:~/ --zone=$ZONE

# Configurar reglas de firewall
print_info "Configurando reglas de firewall..."
gcloud compute firewall-rules create k8s-allow-internal \
  --direction=INGRESS \
  --priority=1000 \
  --network=default \
  --action=ALLOW \
  --rules=all \
  --source-ranges=10.0.0.0/8,192.168.0.0/16,172.16.0.0/12 \
  --target-tags=k8s-master,k8s-worker

gcloud compute firewall-rules create k8s-allow-external \
  --direction=INGRESS \
  --priority=1000 \
  --network=default \
  --action=ALLOW \
  --rules=tcp:6443,tcp:30000-32767 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=k8s-master

gcloud compute firewall-rules create k8s-allow-http \
  --direction=INGRESS \
  --priority=1000 \
  --network=default \
  --action=ALLOW \
  --rules=tcp:80,tcp:443 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=k8s-master,k8s-worker

# Ejecutar script de configuración en el nodo maestro
print_info "Iniciando configuración del nodo maestro..."
gcloud compute ssh $MASTER_NAME --zone=$ZONE --command="chmod +x ~/master_setup.sh && ~/master_setup.sh"

# Obtener comando join del nodo maestro
print_info "Obteniendo comando join del nodo maestro..."
gcloud compute scp $MASTER_NAME:~/join_command.sh ./ --zone=$ZONE
JOIN_COMMAND=$(cat join_command.sh)

# Ejecutar script de configuración en el nodo worker
print_info "Iniciando configuración del nodo worker..."
gcloud compute ssh $WORKER_NAME --zone=$ZONE --command="chmod +x ~/worker_setup.sh && ~/worker_setup.sh"

# Ejecutar comando join en el nodo worker
print_info "Uniendo el nodo worker al clúster..."
gcloud compute ssh $WORKER_NAME --zone=$ZONE --command="sudo $JOIN_COMMAND"

# Etiquetar nodos
print_info "Etiquetando nodos para roles específicos..."
gcloud compute ssh $MASTER_NAME --zone=$ZONE --command="chmod +x ~/label_nodes.sh && ~/label_nodes.sh"

# Mostrar información de las VMs
MASTER_IP=$(gcloud compute instances describe $MASTER_NAME --zone=$ZONE --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
WORKER_IP=$(gcloud compute instances describe $WORKER_NAME --zone=$ZONE --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

print_success "Configuración completada"
echo ""
echo "==================================================================="
echo "Nodo Maestro: $MASTER_NAME"
echo "IP Externa: $MASTER_IP"
echo ""
echo "Nodo Worker: $WORKER_NAME"
echo "IP Externa: $WORKER_IP"
echo ""
echo "Para conectarse al nodo maestro:"
echo "gcloud compute ssh $MASTER_NAME --zone=$ZONE"
echo ""
echo "Para conectarse al nodo worker:"
echo "gcloud compute ssh $WORKER_NAME --zone=$ZONE"
echo ""
echo "El clúster está listo para desplegar la aplicación Coarlumini."
echo "Use el siguiente comando para verificar los nodos:"
echo "kubectl get nodes"
echo "==================================================================="
