#!/bin/bash

# Script para etiquetar nodos y desplegar la aplicación

# Mostrar comandos mientras se ejecutan
set -x

# Verificar que el clúster está funcionando
echo "Verificando estado del clúster..."
kubectl get nodes

echo "Etiquetando nodos para roles específicos..."
# Etiquetar nodo worker para frontend y backend
NODE_WORKER=$(kubectl get nodes | grep -v master | grep -v control-plane | grep Ready | head -1 | awk '{print $1}')
if [ -n "$NODE_WORKER" ]; then
  kubectl label node $NODE_WORKER node-type=frontend,backend --overwrite
  echo "Nodo worker $NODE_WORKER etiquetado para frontend y backend"
fi

# Verificar las etiquetas
kubectl get nodes --show-labels

echo "Clonando el repositorio..."
# Clonar el repositorio
cd $HOME
git clone https://github.com/GuSt4v0CCAM4/example_docker.git
cd example_docker

# Verificar si hay archivos de configuración Kubernetes
if [ -d "k8s" ]; then
  echo "Desplegando la aplicación desde los archivos Kubernetes..."
  
  # Aplicar los manifiestos en orden
  for file in k8s/00-namespace.yaml k8s/01-configmap.yaml k8s/02-secrets.yaml k8s/03-database-pvc.yaml \
             k8s/04-database-deployment.yaml k8s/05-database-service.yaml \
             k8s/06-backend-deployment.yaml k8s/07-backend-pvc.yaml k8s/08-backend-service.yaml \
             k8s/09-frontend-deployment.yaml k8s/10-frontend-pvc.yaml k8s/11-nginx-config.yaml \
             k8s/12-frontend-service.yaml k8s/13-ingress.yaml; do
    if [ -f "$file" ]; then
      echo "Aplicando $file..."
      kubectl apply -f "$file"
    fi
  done
else
  echo "No se encontraron archivos de configuración Kubernetes en el directorio k8s/"
  
  # Crear namespace si no existe
  kubectl create namespace coarlumini --dry-run=client -o yaml | kubectl apply -f -
  
  # TODO: Crear los manifiestos necesarios si no existen en el repositorio
  echo "Es necesario crear los manifiestos de Kubernetes"
fi

# Verificar el estado de los pods
echo "Verificando el estado de los pods..."
kubectl get pods -n coarlumini

# Obtener información de acceso
echo "Información de acceso a la aplicación:"
kubectl get services -n coarlumini

# Si hay servicios NodePort, mostrar URLs de acceso
NODEPORTS=$(kubectl get svc -n coarlumini -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.type}{"\t"}{.spec.ports[0].nodePort}{"\n"}{end}' | grep NodePort)
if [ -n "$NODEPORTS" ]; then
  MASTER_IP=$(hostname -I | awk '{print $1}')
  echo "\nURLs de acceso:\n"
  echo "$NODEPORTS" | while read name type port; do
    echo "$name: http://$MASTER_IP:$port"
  done
fi

# Comprobar si hay un Ingress
INGRESS=$(kubectl get ing -n coarlumini 2>/dev/null)
if [ -n "$INGRESS" ]; then
  echo "\nConfiguración de Ingress:\n"
  kubectl get ing -n coarlumini
fi

echo "\nDespliegue completado. Comprueba el estado de los pods con: kubectl get pods -n coarlumini"
