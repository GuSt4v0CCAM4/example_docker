#!/bin/bash

# Script para desplegar la aplicación Coarlumini en el clúster Kubernetes
# Este script debe ejecutarse en el nodo maestro del clúster

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

# Verificar que kubectl está disponible
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl no está instalado. Este script debe ejecutarse en el nodo maestro."
    exit 1
fi

# Verificar que el clúster está funcionando
if ! kubectl get nodes &> /dev/null; then
    print_error "No se puede acceder al clúster Kubernetes. Verifique que está correctamente configurado."
    exit 1
fi

# Copiar archivos de configuración desde el repositorio
print_info "Copiando archivos de configuración Kubernetes desde el repositorio..."
if [ -d "./k8s" ]; then
    print_success "Directorio k8s encontrado."
else
    print_error "No se encontró el directorio k8s con los archivos de configuración."
    exit 1
fi

# Construir imágenes Docker
print_info "Construyendo imágenes Docker para la aplicación..."

# Imagen de la base de datos
print_info "Construyendo imagen de la base de datos..."
docker build -t coarlumini-database:latest ./database/

# Imagen de backend
print_info "Construyendo imagen de backend..."
docker build -t coarlumini-backend:latest .

# Imagen de frontend
print_info "Construyendo imagen de frontend..."
if [ -d "./frontend" ]; then
    docker build -t coarlumini-frontend:latest ./frontend/
else
    print_error "No se encontró el directorio frontend."
    exit 1
fi

# Etiquetar imágenes para el registro local si existe
REGISTRY_IP=$(kubectl get svc -n kube-system registry -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
if [ -n "$REGISTRY_IP" ]; then
    print_info "Etiquetando imágenes para el registro local $REGISTRY_IP:5000..."
    docker tag coarlumini-database:latest $REGISTRY_IP:5000/coarlumini-database:latest
    docker tag coarlumini-backend:latest $REGISTRY_IP:5000/coarlumini-backend:latest
    docker tag coarlumini-frontend:latest $REGISTRY_IP:5000/coarlumini-frontend:latest

    print_info "Subiendo imágenes al registro local..."
    docker push $REGISTRY_IP:5000/coarlumini-database:latest
    docker push $REGISTRY_IP:5000/coarlumini-backend:latest
    docker push $REGISTRY_IP:5000/coarlumini-frontend:latest

    # Actualizar los manifiestos con las rutas del registro local
    sed -i "s|image: mysql:8.0|image: $REGISTRY_IP:5000/coarlumini-database:latest|g" ./k8s/04-database-deployment.yaml
    sed -i "s|image: php:8.1-apache|image: $REGISTRY_IP:5000/coarlumini-backend:latest|g" ./k8s/06-backend-deployment.yaml
    sed -i "s|image: nginx:stable-alpine|image: $REGISTRY_IP:5000/coarlumini-frontend:latest|g" ./k8s/09-frontend-deployment.yaml
else
    print_warning "No se encontró un registro local. Las imágenes deben estar disponibles en cada nodo."
    # Distribuir imágenes a los nodos worker (esto depende de tu configuración)
    print_info "Guardando imágenes locales..."
    docker save coarlumini-database:latest > coarlumini-database.tar
    docker save coarlumini-backend:latest > coarlumini-backend.tar
    docker save coarlumini-frontend:latest > coarlumini-frontend.tar

    print_info "Distribuyendo imágenes a los nodos worker..."
    WORKER_NODES=$(kubectl get nodes -l '!node-role.kubernetes.io/master' -o jsonpath='{.items[*].metadata.name}')
    for node in $WORKER_NODES; do
        NODE_IP=$(kubectl get node $node -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
        print_info "Enviando imágenes al nodo $node ($NODE_IP)..."
        # Esta parte depende de cómo acceder a tus nodos worker
        # Este es solo un ejemplo y puede que necesites adaptarlo
        scp coarlumini-*.tar $USER@$NODE_IP:~/
        ssh $USER@$NODE_IP "docker load -i ~/coarlumini-database.tar && \
                           docker load -i ~/coarlumini-backend.tar && \
                           docker load -i ~/coarlumini-frontend.tar && \
                           rm ~/coarlumini-*.tar"
    done

    # Limpiar archivos temporales
    rm coarlumini-*.tar

    # Actualizar los manifiestos con las rutas de las imágenes locales
    sed -i "s|image: mysql:8.0|image: coarlumini-database:latest|g" ./k8s/04-database-deployment.yaml
    sed -i "s|image: php:8.1-apache|image: coarlumini-backend:latest|g" ./k8s/06-backend-deployment.yaml
    sed -i "s|image: nginx:stable-alpine|image: coarlumini-frontend:latest|g" ./k8s/09-frontend-deployment.yaml
fi

# Modificar la política de pull de las imágenes a IfNotPresent
print_info "Configurando imagePullPolicy en los manifiestos..."
sed -i '/image: /a \ \ \ \ \ \ \ \ imagePullPolicy: IfNotPresent' ./k8s/04-database-deployment.yaml
sed -i '/image: /a \ \ \ \ \ \ \ \ imagePullPolicy: IfNotPresent' ./k8s/06-backend-deployment.yaml
sed -i '/image: /a \ \ \ \ \ \ \ \ imagePullPolicy: IfNotPresent' ./k8s/09-frontend-deployment.yaml

# Modificar los servicios para usar NodePort
print_info "Configurando servicios como NodePort..."
sed -i 's/type: ClusterIP/type: NodePort/g' ./k8s/08-backend-service.yaml
sed -i 's/type: ClusterIP/type: NodePort/g' ./k8s/12-frontend-service.yaml

# Desplegar la aplicación
print_info "Desplegando la aplicación en Kubernetes..."

# Crear namespace
print_info "Creando namespace..."
kubectl apply -f ./k8s/00-namespace.yaml

# Aplicar ConfigMaps y Secrets
print_info "Aplicando ConfigMaps y Secrets..."
kubectl apply -f ./k8s/01-configmap.yaml
kubectl apply -f ./k8s/02-secrets.yaml
kubectl apply -f ./k8s/11-nginx-config.yaml

# Aplicar PVCs
print_info "Creando volúmenes persistentes..."
kubectl apply -f ./k8s/03-database-pvc.yaml
kubectl apply -f ./k8s/07-backend-pvc.yaml
kubectl apply -f ./k8s/10-frontend-pvc.yaml

# Esperar a que los PVCs estén listos
print_info "Esperando a que los PVCs estén listos..."
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc --all -n coarlumini --timeout=60s || true

# Desplegar base de datos
print_info "Desplegando base de datos..."
kubectl apply -f ./k8s/04-database-deployment.yaml
kubectl apply -f ./k8s/05-database-service.yaml

# Esperar a que la base de datos esté lista
print_info "Esperando a que la base de datos esté lista..."
kubectl wait --namespace=coarlumini --for=condition=ready pod --selector=app=coarlumini-database --timeout=300s || true

# Desplegar backend
print_info "Desplegando backend..."
kubectl apply -f ./k8s/06-backend-deployment.yaml
kubectl apply -f ./k8s/08-backend-service.yaml

# Esperar a que el backend esté listo
print_info "Esperando a que el backend esté listo..."
kubectl wait --namespace=coarlumini --for=condition=ready pod --selector=app=coarlumini-backend --timeout=300s || true

# Desplegar frontend
print_info "Desplegando frontend..."
kubectl apply -f ./k8s/09-frontend-deployment.yaml
kubectl apply -f ./k8s/12-frontend-service.yaml

# Esperar a que el frontend esté listo
print_info "Esperando a que el frontend esté listo..."
kubectl wait --namespace=coarlumini --for=condition=ready pod --selector=app=coarlumini-frontend --timeout=300s || true

# Desplegar Ingress
print_info "Configurando Ingress..."
kubectl apply -f ./k8s/13-ingress.yaml

# Verificar todos los recursos
print_info "Verificando recursos desplegados..."
kubectl get all -n coarlumini

# Mostrar información de acceso
MASTER_IP=$(curl -s ifconfig.me)
print_success "¡Despliegue completado!"
echo ""
echo "======================================================================================="
echo "Aplicación Coarlumini desplegada en el clúster Kubernetes"
echo ""

# Obtener puertos NodePort
BACKEND_PORT=$(kubectl get svc -n coarlumini coarlumini-backend-service -o jsonpath='{.spec.ports[0].nodePort}')
FRONTEND_PORT=$(kubectl get svc -n coarlumini coarlumini-frontend-service -o jsonpath='{.spec.ports[0].nodePort}')

echo "Puedes acceder a la aplicación usando las siguientes URLs:"
echo "- Frontend: http://$MASTER_IP:$FRONTEND_PORT"
echo "- API/Backend: http://$MASTER_IP:$BACKEND_PORT"
echo ""

# Comprobar si hay un Ingress configurado
INGRESS_IP=$(kubectl get ing -n coarlumini -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
if [ -n "$INGRESS_IP" ]; then
    echo "A través del Ingress:"
    echo "- Frontend: http://$INGRESS_IP"
    echo "- API: http://$INGRESS_IP/api"
    echo ""
    echo "Si has configurado DNS, puedes usar:"
    echo "- Frontend: http://coarlumini.example.com"
    echo "- API: http://api.coarlumini.example.com"
fi

echo "======================================================================================="
echo ""
echo "Comandos útiles:"
echo "- Ver pods: kubectl get pods -n coarlumini"
echo "- Ver servicios: kubectl get svc -n coarlumini"
echo "- Ver logs del backend: kubectl logs -f -l app=coarlumini-backend -n coarlumini"
echo "- Ver logs del frontend: kubectl logs -f -l app=coarlumini-frontend -n coarlumini"
echo "- Ver logs de la base de datos: kubectl logs -f -l app=coarlumini-database -n coarlumini"
