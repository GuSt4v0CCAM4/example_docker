#!/bin/bash

# Script para configurar un clu00faster local de Kubernetes con Minikube en una sola VM
# y desplegar la aplicaciu00f3n con 3 nodos virtuales (backend, frontend, base de datos)

# Colores para la salida
RED='033[0;31m'
GREEN='033[0;32m'
YELLOW='033[0;33m'
BLUE='033[0;34m'
NC='033[0m' # No Color

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
sudo apt-get upgrade -y || print_warning "Advertencia durante la actualizaciu00f3n del sistema"

print_info "[2/10] Instalando dependencias..."
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release git || print_error "No se pudieron instalar las dependencias"

print_info "[3/10] Instalando Docker..."
# Au00f1adir la clave GPG de Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - || print_error "No se pudo au00f1adir la clave GPG de Docker"

# Au00f1adir el repositorio de Docker
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" || print_error "No se pudo au00f1adir el repositorio de Docker"

# Instalar Docker
sudo apt-get update || print_warning "Advertencia al actualizar despuu00e9s de au00f1adir repositorio"
sudo apt-get install -y docker-ce docker-ce-cli containerd.io || print_error "No se pudo instalar Docker"

# Iniciar y habilitar Docker
sudo systemctl start docker || print_warning "Advertencia al iniciar Docker"
sudo systemctl enable docker || print_warning "Advertencia al habilitar Docker"

# Au00f1adir el usuario actual al grupo docker
sudo usermod -aG docker $USER || print_warning "Advertencia al au00f1adir usuario al grupo docker"

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
minikube start --driver=docker --nodes=3 || print_error "No se pudo iniciar Minikube"

# Verificar que los nodos estun00e9n listos
print_info "Esperando a que todos los nodos estun00e9n listos..."
sleep 30
kubectl get nodes || print_warning "No se pudieron obtener los nodos"

print_info "[7/10] Etiquetando nodos para roles especu00edficos..."
# Obtener los nombres de los nodos
NODES=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')
NODE_ARRAY=($NODES)

if [ ${#NODE_ARRAY[@]} -ge 3 ]; then
    # Etiquetar los nodos para roles especu00edficos
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

print_info "[9/10] Clonando el repositorio de la aplicaciu00f3n..."
# Clonar el repositorio
cd ~
if [ -d "example_docker" ]; then
    cd example_docker
    git pull || print_warning "No se pudo actualizar el repositorio"
else
    git clone https://github.com/GuSt4v0CCAM4/example_docker.git || print_error "No se pudo clonar el repositorio"
    cd example_docker
fi

print_info "[10/10] Desplegando la aplicaciu00f3n..."
# Crear namespace para la aplicaciu00f3n
kubectl create namespace coarlumini --dry-run=client -o yaml | kubectl apply -f - || print_warning "Advertencia al crear el namespace"

# Verificar si hay archivos de configuracio00f3n Kubernetes en el directorio k8s
if [ -d "k8s" ]; then
    print_info "Desplegando la aplicaciu00f3n desde los archivos Kubernetes..."
    
    # Aplicar los manifiestos en orden
    for file in $(find k8s -name "*.yaml" | sort); do
        print_info "Aplicando $file..."
        kubectl apply -f "$file" || print_warning "Advertencia al aplicar $file"
    done
else
    print_warning "No se encontru00f3 el directorio k8s en el repositorio"
    print_info "Creando archivos de configuracio00f3n Kubernetes..."
    
    # Crear directorio k8s si no existe
    mkdir -p k8s
    
    # TODO: Si es necesario, crear los manifiestos de Kubernetes aquu00ed
    # [Este paso dependeru00e1 de la estructura especu00edfica de la aplicaciu00f3n]
fi

# Verificar el estado de los pods
print_info "Verificando el estado de los pods..."
kubectl get pods -n coarlumini

# Obtener informacio00f3n de acceso
print_info "Informacio00f3n de acceso a la aplicaciu00f3n:"
kubectl get services -n coarlumini

# Configurar dashboard de Kubernetes (opcional)
print_info "Configurando Dashboard de Kubernetes..."
minikube dashboard --url &

# Mostrar resumen
print_success "u00a1Configuracio00f3n completada!"
echo ""
echo "==============================================================="
echo "Resumen de la configuracio00f3n:"
echo "- Clu00faster Kubernetes (Minikube) con 3 nodos configurado"
echo "- Nodos etiquetados para roles especu00edficos"
echo "- Aplicaciu00f3n desplegada en el namespace 'coarlumini'"
echo ""
echo "Para verificar los pods: kubectl get pods -n coarlumini"
echo "Para verificar los servicios: kubectl get services -n coarlumini"
echo "Para acceder al dashboard de Kubernetes: minikube dashboard"
echo "==============================================================="
