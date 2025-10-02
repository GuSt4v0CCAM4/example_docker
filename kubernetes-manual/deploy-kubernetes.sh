#!/bin/bash

# Script simplificado para desplegar Coarlumini en Google Kubernetes Engine (GKE)
# Autor: Coarlumini Team
# Fecha: 2025-10-02

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

# Configuración del proyecto
PROJECT_ID="cloudcomputingunsa"
ZONE="us-central1-a"
CLUSTER_NAME="coarlumini-cluster"
MACHINE_TYPE="e2-medium" # 2 vCPUs, 4GB RAM

# Función para verificar si una herramienta está instalada
check_tool() {
    if ! command -v $1 &> /dev/null; then
        print_error "No se encontró la herramienta $1. Por favor, instálala primero."
        exit 1
    fi
}

# Verificar herramientas necesarias
check_tool gcloud
check_tool kubectl
check_tool docker

# Configurar el proyecto
print_info "Configurando el proyecto: $PROJECT_ID"
gcloud config set project $PROJECT_ID
gcloud config set compute/zone $ZONE

# Habilitar APIs necesarias
print_info "Habilitando APIs necesarias..."
gcloud services enable compute.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable containerregistry.googleapis.com

# Crear clúster GKE
print_info "Creando clúster de Kubernetes..."
gcloud container clusters create $CLUSTER_NAME \
    --num-nodes=3 \
    --machine-type=$MACHINE_TYPE \
    --disk-size=10GB \
    --disk-type=pd-standard

# Obtener credenciales para kubectl
print_info "Obteniendo credenciales del clúster..."
gcloud container clusters get-credentials $CLUSTER_NAME

# Etiquetar nodos para asignarlos a roles específicos
print_info "Etiquetando nodos para roles específicos..."

# Obtener nombres de los nodos
NODES=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')
NODE_ARRAY=($NODES)

if [ ${#NODE_ARRAY[@]} -ge 3 ]; then
    # Asignar etiquetas a los nodos
    kubectl label nodes ${NODE_ARRAY[0]} kubernetes.io/hostname=frontend-node --overwrite
    kubectl label nodes ${NODE_ARRAY[1]} kubernetes.io/hostname=backend-node --overwrite
    kubectl label nodes ${NODE_ARRAY[2]} kubernetes.io/hostname=db-node --overwrite

    print_success "Nodos etiquetados correctamente:"
    echo "Frontend: ${NODE_ARRAY[0]}"
    echo "Backend: ${NODE_ARRAY[1]}"
    echo "Database: ${NODE_ARRAY[2]}"
else
    print_error "No hay suficientes nodos disponibles. Se necesitan al menos 3 nodos."
    exit 1
fi

# Construir y subir imágenes Docker
print_info "Construyendo y subiendo imágenes Docker..."

# Configurar Docker para usar gcloud como credencial helper
gcloud auth configure-docker

# Base de datos
print_info "Construyendo imagen de base de datos..."
docker build -t gcr.io/${PROJECT_ID}/coarlumini-database:latest ../database/
docker push gcr.io/${PROJECT_ID}/coarlumini-database:latest

# Backend
print_info "Construyendo imagen de backend..."
docker build -t gcr.io/${PROJECT_ID}/coarlumini-backend:latest ..
docker push gcr.io/${PROJECT_ID}/coarlumini-backend:latest

# Frontend
print_info "Construyendo imagen de frontend..."
docker build -t gcr.io/${PROJECT_ID}/coarlumini-frontend:latest ../frontend/
docker push gcr.io/${PROJECT_ID}/coarlumini-frontend:latest

# Modificar las rutas de las imágenes en los manifiestos
print_info "Actualizando manifiestos con las rutas correctas de las imágenes..."
sed -i "s|image: mysql:8.0|image: gcr.io/${PROJECT_ID}/coarlumini-database:latest|g" ../k8s/04-database-deployment.yaml
sed -i "s|image: php:8.1-apache|image: gcr.io/${PROJECT_ID}/coarlumini-backend:latest|g" ../k8s/06-backend-deployment.yaml
sed -i "s|image: nginx:stable-alpine|image: gcr.io/${PROJECT_ID}/coarlumini-frontend:latest|g" ../k8s/09-frontend-deployment.yaml

# Desplegar aplicación
print_info "Desplegando aplicación en Kubernetes..."

# Crear namespace y configuración
print_info "Creando namespace y configuración..."
kubectl apply -f ../k8s/00-namespace.yaml
kubectl apply -f ../k8s/01-configmap.yaml
kubectl apply -f ../k8s/02-secrets.yaml
kubectl apply -f ../k8s/11-nginx-config.yaml

# Crear volúmenes persistentes
print_info "Creando volúmenes persistentes..."
kubectl apply -f ../k8s/03-database-pvc.yaml
kubectl apply -f ../k8s/07-backend-pvc.yaml
kubectl apply -f ../k8s/10-frontend-pvc.yaml

# Desplegar base de datos
print_info "Desplegando base de datos..."
kubectl apply -f ../k8s/04-database-deployment.yaml
kubectl apply -f ../k8s/05-database-service.yaml

# Esperar a que la base de datos esté lista
print_info "Esperando a que la base de datos esté lista..."
kubectl wait --namespace=coarlumini --for=condition=ready pod --selector=app=coarlumini-database --timeout=300s || true

# Desplegar backend
print_info "Desplegando backend..."
kubectl apply -f ../k8s/06-backend-deployment.yaml
kubectl apply -f ../k8s/08-backend-service.yaml

# Esperar a que el backend esté listo
print_info "Esperando a que el backend esté listo..."
kubectl wait --namespace=coarlumini --for=condition=ready pod --selector=app=coarlumini-backend --timeout=300s || true

# Desplegar frontend
print_info "Desplegando frontend..."
kubectl apply -f ../k8s/09-frontend-deployment.yaml
kubectl apply -f ../k8s/12-frontend-service.yaml

# Esperar a que el frontend esté listo
print_info "Esperando a que el frontend esté listo..."
kubectl wait --namespace=coarlumini --for=condition=ready pod --selector=app=coarlumini-frontend --timeout=300s || true

# Desplegar Ingress
print_info "Configurando Ingress..."
kubectl apply -f ../k8s/13-ingress.yaml

# Verificar recursos
print_info "Verificando recursos desplegados..."
kubectl get all -n coarlumini

# Mostrar IP del Ingress (puede tardar unos minutos en asignarse)
print_info "Esperando a que el Ingress tenga una IP asignada..."
sleep 30
INGRESS_IP=$(kubectl get ingress -n coarlumini -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pendiente")

print_success "¡Despliegue completado!"
echo ""
echo "======================================================================================="
echo "Aplicación Coarlumini desplegada en el clúster: $CLUSTER_NAME"
echo ""
if [ "$INGRESS_IP" != "pendiente" ]; then
    echo "Accede a la aplicación en:"
    echo "- Frontend: http://$INGRESS_IP"
    echo "- API: http://$INGRESS_IP/api"
else
    echo "El Ingress aún no tiene una IP asignada. Verifica en unos minutos con:"
    echo "kubectl get ingress -n coarlumini"
fi
echo "======================================================================================="
echo ""
echo "Para ver los pods: kubectl get pods -n coarlumini"
echo "Para ver los servicios: kubectl get services -n coarlumini"
echo "Para ver los logs del backend: kubectl logs -f -l app=coarlumini-backend -n coarlumini"
echo "Para ver los logs del frontend: kubectl logs -f -l app=coarlumini-frontend -n coarlumini"
