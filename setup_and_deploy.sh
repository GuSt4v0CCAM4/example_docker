#!/bin/bash

# Script para configurar Kubernetes y desplegar aplicación Coarlumini
# Este script debe ejecutarse en el nodo maestro

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

# Configuración de Kubernetes
setup_kubernetes() {
    print_info "Configurando Kubernetes en el nodo maestro..."

    # Instalar Docker
    print_info "Instalando Docker..."
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    sudo usermod -aG docker $USER
    sudo systemctl enable docker
    sudo systemctl start docker

    # Configurar containerd para Kubernetes
    print_info "Configurando containerd..."
    cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

    sudo modprobe overlay
    sudo modprobe br_netfilter

    # Configuración de red para Kubernetes
    print_info "Configurando parámetros de red..."
    cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

    sudo sysctl --system

    # Configurar containerd
    print_info "Configurando containerd para Kubernetes..."
    sudo mkdir -p /etc/containerd
    sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
    sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
    sudo systemctl restart containerd

    # Instalar Kubernetes
    print_info "Instalando Kubernetes..."
    sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
    echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl

    # Deshabilitar swap
    print_info "Deshabilitando swap..."
    sudo swapoff -a
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

    # Iniciar el clúster
    print_info "Inicializando el clúster de Kubernetes..."
    sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --control-plane-endpoint=$(hostname -I | awk '{print $1}')

    # Configurar kubectl para el usuario actual
    print_info "Configurando kubectl..."
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

    # Instalar red Flannel
    print_info "Instalando red Flannel..."
    kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

    # Permitir que el nodo maestro ejecute pods
    print_info "Permitiendo que el nodo maestro ejecute pods..."
    kubectl taint nodes --all node-role.kubernetes.io/control-plane-
    kubectl taint nodes --all node-role.kubernetes.io/master-

    print_success "Clúster de Kubernetes inicializado correctamente."
}

# Configurar nodos virtuales para multi-nodos en un solo nodo físico
setup_virtual_nodes() {
    print_info "Configurando nodos virtuales en el clúster..."

    # Crear namespaces para los nodos virtuales
    kubectl create namespace backend
    kubectl create namespace frontend
    kubectl create namespace database

    # Etiquetar el nodo maestro
    NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
    kubectl label node $NODE_NAME kubernetes.io/hostname=all-nodes

    print_success "Nodos virtuales configurados."
}

# Clonar el repositorio
clone_repository() {
    print_info "Clonando repositorio desde GitHub..."
    if [ -d "example_docker" ]; then
        print_warning "Directorio example_docker ya existe. Eliminándolo..."
        rm -rf example_docker
    fi

    git clone https://github.com/GuSt4v0CCAM4/example_docker.git
    if [ $? -ne 0 ]; then
        print_error "Error al clonar el repositorio."
        exit 1
    fi

    print_success "Repositorio clonado correctamente."
}

# Crear configuraciones para el despliegue
create_deployment_files() {
    print_info "Creando archivos de configuración para Kubernetes..."

    mkdir -p example_docker/kubernetes

    # Crear namespace
    cat <<EOF > example_docker/kubernetes/00-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: coarlumini
EOF

    # Crear ConfigMap
    cat <<EOF > example_docker/kubernetes/01-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coarlumini-config
  namespace: coarlumini
data:
  APP_ENV: "production"
  APP_DEBUG: "false"
  APP_URL: "http://localhost"
  DB_HOST: "coarlumini-database-service"
  DB_PORT: "3306"
  DB_DATABASE: "coarlumini"
EOF

    # Crear Secret
    cat <<EOF > example_docker/kubernetes/02-secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: coarlumini-secrets
  namespace: coarlumini
type: Opaque
stringData:
  APP_KEY: "base64:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  DB_USERNAME: "root"
  DB_PASSWORD: "root"
EOF

    # Crear PVC para la base de datos
    cat <<EOF > example_docker/kubernetes/03-database-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-data-pvc
  namespace: coarlumini
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

    # Deployment de la base de datos
    cat <<EOF > example_docker/kubernetes/04-database-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: coarlumini-database
  namespace: coarlumini
spec:
  replicas: 1
  selector:
    matchLabels:
      app: coarlumini-database
  template:
    metadata:
      labels:
        app: coarlumini-database
    spec:
      nodeName: ${NODE_NAME}
      containers:
      - name: mysql
        image: mysql:8.0
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 3306
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: coarlumini-secrets
              key: DB_PASSWORD
        - name: MYSQL_DATABASE
          valueFrom:
            configMapKeyRef:
              name: coarlumini-config
              key: DB_DATABASE
        volumeMounts:
        - name: mysql-data
          mountPath: /var/lib/mysql
      volumes:
      - name: mysql-data
        persistentVolumeClaim:
          claimName: mysql-data-pvc
EOF

    # Servicio de la base de datos
    cat <<EOF > example_docker/kubernetes/05-database-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: coarlumini-database-service
  namespace: coarlumini
spec:
  selector:
    app: coarlumini-database
  ports:
  - port: 3306
    targetPort: 3306
  type: ClusterIP
EOF

    # Deployment del backend
    cat <<EOF > example_docker/kubernetes/06-backend-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: coarlumini-backend
  namespace: coarlumini
spec:
  replicas: 1
  selector:
    matchLabels:
      app: coarlumini-backend
  template:
    metadata:
      labels:
        app: coarlumini-backend
    spec:
      nodeName: ${NODE_NAME}
      containers:
      - name: laravel
        image: example_docker_api:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
        env:
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: coarlumini-config
              key: DB_HOST
        - name: DB_PORT
          valueFrom:
            configMapKeyRef:
              name: coarlumini-config
              key: DB_PORT
        - name: DB_DATABASE
          valueFrom:
            configMapKeyRef:
              name: coarlumini-config
              key: DB_DATABASE
        - name: DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: coarlumini-secrets
              key: DB_USERNAME
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: coarlumini-secrets
              key: DB_PASSWORD
EOF

    # Servicio del backend
    cat <<EOF > example_docker/kubernetes/07-backend-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: coarlumini-backend-service
  namespace: coarlumini
spec:
  selector:
    app: coarlumini-backend
  ports:
  - port: 80
    targetPort:
