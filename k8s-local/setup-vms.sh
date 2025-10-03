#!/bin/bash

# Este script configura tres VMs de Google Cloud para ser utilizadas como nodos de un clúster de Kubernetes
# que ejecutará la aplicación Coarlumini con tres nodos: frontend, backend y base de datos.

set -e

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

# Verificar si gcloud está instalado
if ! command -v gcloud &> /dev/null; then
    print_error "gcloud no está instalado. Por favor, instálalo primero."
    exit 1
fi

# Verificar si el usuario está autenticado en gcloud
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q '@'; then
    print_error "No estás autenticado en gcloud. Por favor, ejecuta 'gcloud auth login'"
    exit 1
fi

# Establecer ID del proyecto de GCP
PROJECT_ID="cloudcomputingunsa"
print_info "Usando el proyecto: $PROJECT_ID"

# Verificar si el proyecto existe
if ! gcloud projects describe $PROJECT_ID &> /dev/null; then
    print_error "El proyecto $PROJECT_ID no existe o no tienes acceso a él."
    print_info "Asegúrate de tener permisos en el proyecto y estar autenticado con 'gcloud auth login'."
    exit 1
fi

# Configurar el proyecto por defecto
gcloud config set project $PROJECT_ID
print_success "Proyecto configurado: $PROJECT_ID"

# Establecer zona para las VMs
ZONE="us-central1-a"
print_info "Usando la zona: $ZONE"
gcloud config set compute/zone $ZONE

# Configuración de las VMs
VM_PREFIX="coarlumini"
MACHINE_TYPE="e2-medium"  # 2 vCPUs, 4GB RAM
BOOT_DISK_SIZE="30GB"
BOOT_DISK_TYPE="pd-standard"
IMAGE_FAMILY="ubuntu-2004-lts"
IMAGE_PROJECT="ubuntu-os-cloud"

# Crear VMs para los nodos del clúster
create_vm() {
    local NODE_NAME="$1"
    local LABELS="$2"

    if gcloud compute instances describe ${VM_PREFIX}-${NODE_NAME} &>/dev/null; then
        print_warning "La VM ${VM_PREFIX}-${NODE_NAME} ya existe. Omitiendo creación."
        return 0
    fi

    print_info "Creando VM para $NODE_NAME..."

    gcloud compute instances create ${VM_PREFIX}-${NODE_NAME} \
        --zone=$ZONE \
        --machine-type=$MACHINE_TYPE \
        --subnet=default \
        --network-tier=PREMIUM \
        --maintenance-policy=MIGRATE \
        --image-family=$IMAGE_FAMILY \
        --image-project=$IMAGE_PROJECT \
        --boot-disk-size=$BOOT_DISK_SIZE \
        --boot-disk-type=$BOOT_DISK_TYPE \
        --boot-disk-device-name=${VM_PREFIX}-${NODE_NAME} \
        --tags=http-server,https-server,kubernetes \
        --labels="role=${NODE_NAME},${LABELS}" \
        --metadata="startup-script=#! /bin/bash
        # Actualizar paquetes
        sudo apt-get update && sudo apt-get upgrade -y

        # Instalar Docker
        sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository 'deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable'
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io
        sudo systemctl enable docker
        sudo systemctl start docker
        sudo usermod -aG docker \$USER

        # Instalar herramientas necesarias
        sudo apt-get install -y apt-transport-https curl git

        # Instalar kubectl
        curl -LO 'https://dl.k8s.io/release/stable.txt'
        RELEASE=\$(cat stable.txt)
        curl -LO \"https://dl.k8s.io/release/\$RELEASE/bin/linux/amd64/kubectl\"
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

        # Instalar kubeadm, kubelet
        curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
        echo 'deb http://apt.kubernetes.io/ kubernetes-xenial main' | sudo tee /etc/apt/sources.list.d/kubernetes.list
        sudo apt-get update
        sudo apt-get install -y kubelet kubeadm
        sudo apt-mark hold kubelet kubeadm

        # Deshabilitar swap (requerido para Kubernetes)
        sudo swapoff -a
        sudo sed -i '/ swap / s/^/#/' /etc/fstab

        # Configurar sysctl para Kubernetes
        cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
        sudo sysctl --system
        "

    print_success "VM ${VM_PREFIX}-${NODE_NAME} creada exitosamente."
}

# Crear las tres VMs
print_info "Comenzando la creación de las VMs..."
create_vm "master" "kubernetes=master"
create_vm "frontend" "kubernetes=node"
create_vm "backend" "kubernetes=node"
create_vm "database" "kubernetes=node"

# Esperar a que las VMs estén listas
print_info "Esperando a que las VMs estén listas..."
sleep 30

# Configurar reglas de firewall
print_info "Configurando reglas de firewall..."

# Permitir tráfico HTTP/HTTPS
gcloud compute firewall-rules create ${VM_PREFIX}-allow-http \
    --direction=INGRESS \
    --priority=1000 \
    --network=default \
    --action=ALLOW \
    --rules=tcp:80,tcp:443 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=http-server,https-server

# Permitir tráfico Kubernetes interno
gcloud compute firewall-rules create ${VM_PREFIX}-allow-k8s-internal \
    --direction=INGRESS \
    --priority=1000 \
    --network=default \
    --action=ALLOW \
    --rules=tcp:6443,tcp:2379-2380,tcp:10250,tcp:10251,tcp:10252,udp:8472,tcp:30000-32767 \
    --source-ranges=10.0.0.0/8 \
    --target-tags=kubernetes

print_success "Reglas de firewall configuradas exitosamente."

# Obtener las IPs de las VMs
MASTER_IP=$(gcloud compute instances describe ${VM_PREFIX}-master --format='get(networkInterfaces[0].networkIP)')
MASTER_EXTERNAL_IP=$(gcloud compute instances describe ${VM_PREFIX}-master --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
FRONTEND_IP=$(gcloud compute instances describe ${VM_PREFIX}-frontend --format='get(networkInterfaces[0].networkIP)')
BACKEND_IP=$(gcloud compute instances describe ${VM_PREFIX}-backend --format='get(networkInterfaces[0].networkIP)')
DATABASE_IP=$(gcloud compute instances describe ${VM_PREFIX}-database --format='get(networkInterfaces[0].networkIP)')

# Generar archivo de configuración para Kubernetes
print_info "Generando archivo de configuración para inicializar el clúster Kubernetes..."

cat > setup-k8s-cluster.sh <<EOL
#!/bin/bash

# Conectarse al nodo master e inicializar el clúster
echo "Iniciando configuración del clúster Kubernetes en el nodo master..."
gcloud compute ssh ${VM_PREFIX}-master --command="
    sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$MASTER_IP

    # Configurar kubectl para el usuario actual
    mkdir -p \$HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config
    sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config

    # Instalar red Flannel
    kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

    # Generar el token de unión y guardarlo
    KUBEADM_JOIN_CMD=\$(sudo kubeadm token create --print-join-command)
    echo \$KUBEADM_JOIN_CMD > join-command.sh
"

# Obtener el comando join del nodo master
echo "Obteniendo comando join del nodo master..."
gcloud compute scp ${VM_PREFIX}-master:~/join-command.sh .
JOIN_COMMAND=\$(cat join-command.sh)

# Unir el nodo frontend al clúster
echo "Uniendo nodo frontend al clúster..."
gcloud compute ssh ${VM_PREFIX}-frontend --command="
    sudo \$JOIN_COMMAND
    kubectl label node ${VM_PREFIX}-frontend kubernetes.io/hostname=frontend-node
"

# Unir el nodo backend al clúster
echo "Uniendo nodo backend al clúster..."
gcloud compute ssh ${VM_PREFIX}-backend --command="
    sudo \$JOIN_COMMAND
    kubectl label node ${VM_PREFIX}-backend kubernetes.io/hostname=backend-node
"

# Unir el nodo de base de datos al clúster
echo "Uniendo nodo de base de datos al clúster..."
gcloud compute ssh ${VM_PREFIX}-database --command="
    sudo \$JOIN_COMMAND
    kubectl label node ${VM_PREFIX}-database kubernetes.io/hostname=db-node
"

# Verificar los nodos
echo "Verificando los nodos del clúster..."
gcloud compute ssh ${VM_PREFIX}-master --command="
    kubectl get nodes -o wide
"

echo "Configuración del clúster Kubernetes completada."
EOL

# Hacer el script ejecutable
chmod +x setup-k8s-cluster.sh

# Generar archivo para desplegar la aplicación
print_info "Generando archivo para desplegar la aplicación Coarlumini en el clúster..."

cat > deploy-coarlumini.sh <<EOL
#!/bin/bash

# Copiar los manifiestos de Kubernetes al nodo master
echo "Copiando los manifiestos de Kubernetes al nodo master..."
gcloud compute scp --recurse ./k8s ${VM_PREFIX}-master:~/k8s

# Aplicar los manifiestos en orden
echo "Desplegando la aplicación Coarlumini en el clúster..."
gcloud compute ssh ${VM_PREFIX}-master --command="
    # Crear namespace
    kubectl apply -f ~/k8s/00-namespace.yaml

    # Aplicar configmaps y secrets
    kubectl apply -f ~/k8s/01-configmap.yaml
    kubectl apply -f ~/k8s/02-secrets.yaml
    kubectl apply -f ~/k8s/11-nginx-config.yaml

    # Aplicar PVCs
    kubectl apply -f ~/k8s/03-database-pvc.yaml
    kubectl apply -f ~/k8s/07-backend-pvc.yaml
    kubectl apply -f ~/k8s/10-frontend-pvc.yaml

    # Desplegar base de datos
    kubectl apply -f ~/k8s/04-database-deployment.yaml
    kubectl apply -f ~/k8s/05-database-service.yaml

    # Esperar a que la base de datos esté lista
    echo 'Esperando a que la base de datos esté lista...'
    kubectl wait --namespace=coarlumini --for=condition=ready pod --selector=app=coarlumini-database --timeout=300s

    # Desplegar backend
    kubectl apply -f ~/k8s/06-backend-deployment.yaml
    kubectl apply -f ~/k8s/08-backend-service.yaml

    # Esperar a que el backend esté listo
    echo 'Esperando a que el backend esté listo...'
    kubectl wait --namespace=coarlumini --for=condition=ready pod --selector=app=coarlumini-backend --timeout=300s

    # Desplegar frontend
    kubectl apply -f ~/k8s/09-frontend-deployment.yaml
    kubectl apply -f ~/k8s/12-frontend-service.yaml

    # Esperar a que el frontend esté listo
    echo 'Esperando a que el frontend esté listo...'
    kubectl wait --namespace=coarlumini --for=condition=ready pod --selector=app=coarlumini-frontend --timeout=300s

    # Aplicar Ingress
    kubectl apply -f ~/k8s/13-ingress.yaml

    # Verificar todos los recursos
    kubectl get all -n coarlumini
"

echo "Despliegue de Coarlumini completado."
EOL

# Hacer el script ejecutable
chmod +x deploy-coarlumini.sh

print_success "Configuración completada exitosamente."
print_info "Las siguientes IPs están disponibles:"
echo "Nodo Master: $MASTER_EXTERNAL_IP (interno: $MASTER_IP)"
echo "Nodo Frontend: $(gcloud compute instances describe ${VM_PREFIX}-frontend --format='get(networkInterfaces[0].accessConfigs[0].natIP)') (interno: $FRONTEND_IP)"
echo "Nodo Backend: $(gcloud compute instances describe ${VM_PREFIX}-backend --format='get(networkInterfaces[0].accessConfigs[0].natIP)') (interno: $BACKEND_IP)"
echo "Nodo Database: $(gcloud compute instances describe ${VM_PREFIX}-database --format='get(networkInterfaces[0].accessConfigs[0].natIP)') (interno: $DATABASE_IP)"

print_info "Para inicializar el clúster Kubernetes, ejecuta: ./setup-k8s-cluster.sh"
print_info "Para desplegar la aplicación Coarlumini, ejecuta: ./deploy-coarlumini.sh"
