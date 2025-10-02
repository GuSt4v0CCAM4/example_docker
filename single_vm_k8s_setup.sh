#!/bin/bash

# Script para configurar un cluster local de Kubernetes con Minikube en una sola VM
# y desplegar la aplicación con 3 nodos virtuales (backend, frontend, base de datos)

# Colores para la salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funciones para mensajes
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
    exit 1
}

# Mostrar comandos mientras se ejecutan
set -e

print_info "[1/10] Actualizando el sistema..."
sudo apt-get update || print_error "No se pudo actualizar el sistema"
sudo apt-get upgrade -y || print_warning "Advertencia durante la actualización del sistema"

print_info "[2/10] Instalando dependencias..."
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release git conntrack || print_error "No se pudieron instalar las dependencias"

print_info "[3/10] Instalando Docker..."
# Añadir la clave GPG de Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - || print_error "No se pudo añadir la clave GPG de Docker"

# Añadir el repositorio de Docker
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" || print_error "No se pudo añadir el repositorio de Docker"

# Instalar Docker
sudo apt-get update || print_warning "Advertencia al actualizar después de añadir repositorio"
sudo apt-get install -y docker-ce docker-ce-cli containerd.io || print_error "No se pudo instalar Docker"

# Iniciar y habilitar Docker
sudo systemctl start docker || print_warning "Advertencia al iniciar Docker"
sudo systemctl enable docker || print_warning "Advertencia al habilitar Docker"

# Añadir el usuario actual al grupo docker
sudo usermod -aG docker $USER || print_warning "Advertencia al añadir usuario al grupo docker"

# Aplicar cambios de grupo sin cerrar sesión
newgrp docker << EONG

print_info "[4/10] Instalando kubectl..."
# Descargar e instalar kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" || print_error "No se pudo descargar kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl || print_error "No se pudo instalar kubectl"

print_info "[5/10] Instalando Minikube..."
# Descargar e instalar Minikube
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 || print_error "No se pudo descargar Minikube"
sudo install minikube /usr/local/bin/ || print_error "No se pudo instalar Minikube"

print_info "[6/10] Iniciando Minikube con 3 nodos..."
# Iniciar Minikube con 3 nodos
minikube start --driver=docker --nodes=3 --memory=2048 --cpus=2 || print_error "No se pudo iniciar Minikube"

# Verificar que los nodos estén listos
print_info "Esperando a que todos los nodos estén listos..."
sleep 30
kubectl get nodes || print_warning "No se pudieron obtener los nodos"

print_info "[7/10] Etiquetando nodos para roles específicos..."
# Obtener los nombres de los nodos
NODES=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')
NODE_ARRAY=($NODES)

if [ ${#NODE_ARRAY[@]} -ge 3 ]; then
    # Etiquetar los nodos para roles específicos
    kubectl label node ${NODE_ARRAY[0]} node-role=database || print_warning "No se pudo etiquetar el nodo de base de datos"
    kubectl label node ${NODE_ARRAY[1]} node-role=backend || print_warning "No se pudo etiquetar el nodo de backend"
    kubectl label node ${NODE_ARRAY[2]} node-role=frontend || print_warning "No se pudo etiquetar el nodo de frontend"
    
    print_success "Nodos etiquetados correctamente:"
    echo "Base de datos: ${NODE_ARRAY[0]}"
    echo "Backend: ${NODE_ARRAY[1]}"
    echo "Frontend: ${NODE_ARRAY[2]}"
else
    print_error "No hay suficientes nodos disponibles. Se necesitan 3 nodos."
fi

print_info "[8/10] Verificando los nodos y sus etiquetas..."
kubectl get nodes --show-labels

print_info "[9/10] Clonando el repositorio de la aplicación..."
# Clonar el repositorio
cd ~
if [ -d "example_docker" ]; then
    cd example_docker
    git pull || print_warning "No se pudo actualizar el repositorio"
else
    git clone https://github.com/GuSt4v0CCAM4/example_docker.git || print_error "No se pudo clonar el repositorio"
    cd example_docker
fi

print_info "[10/10] Desplegando la aplicación..."
# Crear namespace para la aplicación
kubectl create namespace coarlumini --dry-run=client -o yaml | kubectl apply -f - || print_warning "Advertencia al crear el namespace"

# Verificar si hay archivos de configuración Kubernetes en el directorio k8s
if [ -d "k8s" ]; then
    print_info "Desplegando la aplicación desde los archivos Kubernetes..."
    
    # Aplicar los manifiestos en orden
    for file in $(find k8s -name "*.yaml" | sort); do
        print_info "Aplicando $file..."
        kubectl apply -f "$file" || print_warning "Advertencia al aplicar $file"
    done
else
    print_warning "No se encontró el directorio k8s en el repositorio"
    print_info "Creando archivos de configuración Kubernetes básicos..."
    
    # Crear directorio k8s si no existe
    mkdir -p k8s
    
    # Crear configuración básica para la aplicación
    # Este es un ejemplo simplificado. Ajusta según tus necesidades reales.
    
    # ConfigMap
    cat > k8s/01-configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: coarlumini-config
  namespace: coarlumini
data:
  DB_HOST: "database-service"
  DB_PORT: "3306"
  DB_DATABASE: "coarlumini"
EOF
    
    # Secret
    cat > k8s/02-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: coarlumini-secret
  namespace: coarlumini
type: Opaque
stringData:
  DB_USERNAME: "coarlumini"
  DB_PASSWORD: "password123"
EOF
    
    # Base de datos
    cat > k8s/03-database.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
  namespace: coarlumini
spec:
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      nodeSelector:
        node-role: database
      containers:
      - name: mysql
        image: mysql:5.7
        ports:
        - containerPort: 3306
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: coarlumini-secret
              key: DB_PASSWORD
        - name: MYSQL_DATABASE
          valueFrom:
            configMapKeyRef:
              name: coarlumini-config
              key: DB_DATABASE
        - name: MYSQL_USER
          valueFrom:
            secretKeyRef:
              name: coarlumini-secret
              key: DB_USERNAME
        - name: MYSQL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: coarlumini-secret
              key: DB_PASSWORD
---
apiVersion: v1
kind: Service
metadata:
  name: database-service
  namespace: coarlumini
spec:
  selector:
    app: database
  ports:
  - port: 3306
    targetPort: 3306
  type: ClusterIP
EOF
    
    # Backend
    cat > k8s/04-backend.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: coarlumini
spec:
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      nodeSelector:
        node-role: backend
      containers:
      - name: backend
        image: php:8.1-apache
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
              name: coarlumini-secret
              key: DB_USERNAME
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: coarlumini-secret
              key: DB_PASSWORD
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: coarlumini
spec:
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 80
  type: NodePort
EOF
    
    # Frontend
    cat > k8s/05-frontend.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: coarlumini
spec:
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      nodeSelector:
        node-role: frontend
      containers:
      - name: frontend
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
  namespace: coarlumini
spec:
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
  type: NodePort
EOF

    # Aplicar los manifiestos
    for file in k8s/*.yaml; do
        print_info "Aplicando $file..."
        kubectl apply -f "$file" || print_warning "Advertencia al aplicar $file"
    done
fi

# Verificar el estado de los pods
print_info "Verificando el estado de los pods..."
kubectl get pods -n coarlumini

# Obtener información de acceso
print_info "Información de acceso a la aplicación:"
kubectl get services -n coarlumini

# Configurar dashboard de Kubernetes
print_info "Habilitando y abriendo Dashboard de Kubernetes..."
minikube dashboard --url &

EONG

# Mostrar resumen
print_success "¡Configuración completada!"
echo ""
echo "==============================================================="
echo "Resumen de la configuración:"
echo "- Cluster Kubernetes (Minikube) con 3 nodos configurado"
echo "- Nodos etiquetados para roles específicos"
echo "- Aplicación desplegada en el namespace 'coarlumini'"
echo ""
echo "Para verificar los pods: kubectl get pods -n coarlumini"
echo "Para verificar los servicios: kubectl get services -n coarlumini"
echo "Para acceder al dashboard de Kubernetes: minikube dashboard"
echo "==============================================================="
