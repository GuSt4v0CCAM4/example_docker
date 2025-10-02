# Despliegue Manual de Coarlumini en Google Kubernetes Engine (GKE)

Este documento proporciona instrucciones paso a paso para desplegar la aplicación Coarlumini en Google Kubernetes Engine (GKE) usando 3 nodos dedicados para frontend, backend y base de datos.

## Prerrequisitos

1. **Cuenta de Google Cloud Platform** con facturación habilitada
2. **Proyecto de GCP** creado (en este caso: "cloudcomputingunsa")
3. **gcloud CLI** instalado y configurado
4. **kubectl** instalado
5. **Docker** instalado (para construir las imágenes)

## 1. Configuración Inicial

### Configurar gcloud CLI

```bash
# Iniciar sesión en Google Cloud
gcloud auth login

# Configurar el proyecto
gcloud config set project cloudcomputingunsa

# Establecer la zona por defecto
gcloud config set compute/zone us-central1-a
```

### Habilitar las APIs necesarias

```bash
# Habilitar Compute Engine API
gcloud services enable compute.googleapis.com

# Habilitar Kubernetes Engine API
gcloud services enable container.googleapis.com

# Habilitar Container Registry API
gcloud services enable containerregistry.googleapis.com

# Habilitar Artifact Registry API (opcional, para GCR)
gcloud services enable artifactregistry.googleapis.com
```

## 2. Crear el Clúster GKE

```bash
# Crear un clúster con 3 nodos
gcloud container clusters create coarlumini-cluster \
    --num-nodes=3 \
    --machine-type=e2-medium \
    --disk-size=10GB \
    --disk-type=pd-standard \
    --zone=us-central1-a

# Obtener credenciales para kubectl
gcloud container clusters get-credentials coarlumini-cluster
```

## 3. Etiquetar los Nodos para Roles Específicos

```bash
# Obtener la lista de nodos
kubectl get nodes

# Etiquetar cada nodo para su rol específico (reemplaza NODE_NAME_X con los nombres reales)
kubectl label nodes NODE_NAME_1 kubernetes.io/hostname=frontend-node
kubectl label nodes NODE_NAME_2 kubernetes.io/hostname=backend-node
kubectl label nodes NODE_NAME_3 kubernetes.io/hostname=db-node

# Verificar las etiquetas
kubectl get nodes --show-labels
```

## 4. Construir y Publicar Imágenes Docker

### Construir Imagen de Base de Datos

```bash
# Navegar al directorio de la base de datos
cd ../database

# Construir la imagen
docker build -t gcr.io/cloudcomputingunsa/coarlumini-database:latest .

# Publicar la imagen
docker push gcr.io/cloudcomputingunsa/coarlumini-database:latest
```

### Construir Imagen de Backend

```bash
# Navegar al directorio raíz
cd ..

# Construir la imagen
docker build -t gcr.io/cloudcomputingunsa/coarlumini-backend:latest .

# Publicar la imagen
docker push gcr.io/cloudcomputingunsa/coarlumini-backend:latest
```

### Construir Imagen de Frontend

```bash
# Navegar al directorio del frontend
cd frontend

# Construir la imagen
docker build -t gcr.io/cloudcomputingunsa/coarlumini-frontend:latest .

# Publicar la imagen
docker push gcr.io/cloudcomputingunsa/coarlumini-frontend:latest
```

## 5. Aplicar los Manifiestos de Kubernetes

Aplica los manifiestos en este orden:

```bash
# Crear el namespace
kubectl apply -f ../k8s/00-namespace.yaml

# ConfigMaps y Secrets
kubectl apply -f ../k8s/01-configmap.yaml
kubectl apply -f ../k8s/02-secrets.yaml
kubectl apply -f ../k8s/11-nginx-config.yaml

# Volúmenes persistentes
kubectl apply -f ../k8s/03-database-pvc.yaml
kubectl apply -f ../k8s/07-backend-pvc.yaml
kubectl apply -f ../k8s/10-frontend-pvc.yaml

# Base de datos
kubectl apply -f ../k8s/04-database-deployment.yaml
kubectl apply -f ../k8s/05-database-service.yaml

# Esperar a que la base de datos esté lista
kubectl wait --namespace=coarlumini --for=condition=ready pod --selector=app=coarlumini-database --timeout=300s

# Backend
kubectl apply -f ../k8s/06-backend-deployment.yaml
kubectl apply -f ../k8s/08-backend-service.yaml

# Frontend
kubectl apply -f ../k8s/09-frontend-deployment.yaml
kubectl apply -f ../k8s/12-frontend-service.yaml

# Ingress
kubectl apply -f ../k8s/13-ingress.yaml
```

## 6. Verificar el Despliegue

```bash
# Ver todos los recursos en el namespace
kubectl get all -n coarlumini

# Ver pods
kubectl get pods -n coarlumini

# Ver servicios
kubectl get services -n coarlumini

# Ver ingress
kubectl get ingress -n coarlumini
```

## 7. Acceder a la Aplicación

Una vez que el ingress tenga una IP asignada:

```bash
# Obtener la IP del ingress
kubectl get ingress -n coarlumini
```

Accede a la aplicación:
- Frontend: http://IP_INGRESS
- API: http://IP_INGRESS/api

## 8. Solución de Problemas

### Verificar Logs de los Pods

```bash
# Logs del backend
kubectl logs -f -l app=coarlumini-backend -n coarlumini

# Logs del frontend
kubectl logs -f -l app=coarlumini-frontend -n coarlumini

# Logs de la base de datos
kubectl logs -f -l app=coarlumini-database -n coarlumini
```

### Verificar Eventos

```bash
kubectl get events -n coarlumini
```

### Reiniciar un Despliegue

```bash
kubectl rollout restart deployment/coarlumini-backend -n coarlumini
```

## 9. Limpieza

Cuando ya no necesites el clúster:

```bash
gcloud container clusters delete coarlumini-cluster
```

## Referencias

- [Documentación de GKE](https://cloud.google.com/kubernetes-engine/docs)
- [Kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)