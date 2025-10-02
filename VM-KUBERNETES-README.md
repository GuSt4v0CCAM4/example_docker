# Despliegue de Coarlumini en una VM con Kubernetes (Minikube)

Este documento describe cómo desplegar la aplicación Coarlumini en una única máquina virtual (VM) de Google Cloud que ejecuta Minikube para crear un clúster de Kubernetes con 3 nodos.

## Requisitos

- Cuenta de Google Cloud Platform con facturación habilitada
- Proyecto de GCP creado (en este caso: "cloudcomputingunsa")
- gcloud CLI instalado y configurado en tu máquina local

## Proceso de Despliegue

### 1. Crear y Configurar la VM

El script `setup-minikube-vm.sh` automatiza la creación de una VM en Google Cloud y la configuración de Minikube:

```bash
# Dar permisos de ejecución al script
chmod +x setup-minikube-vm.sh

# Ejecutar el script
./setup-minikube-vm.sh
```

Este script realiza las siguientes acciones:
1. Crea una VM en Google Cloud (e2-standard-4: 4 vCPUs, 16GB RAM)
2. Instala Docker, kubectl y Minikube en la VM
3. Configura Minikube para ejecutar un clúster con 3 nodos
4. Etiqueta los nodos para los diferentes componentes (frontend, backend, base de datos)
5. Configura reglas de firewall para exponer los servicios

### 2. Desplegar la Aplicación

Una vez creada y configurada la VM, debes conectarte a ella y ejecutar el script de despliegue:

```bash
# Conectarte a la VM (reemplaza ZONE con la zona utilizada, por defecto us-central1-b)
gcloud compute ssh coarlumini-minikube --zone=ZONE

# En la VM, ejecuta el script de despliegue
cd ~/
./deploy-to-minikube.sh
```

El script `deploy-to-minikube.sh` realiza las siguientes acciones:
1. Verifica que Minikube esté funcionando correctamente
2. Construye las imágenes Docker para los tres componentes
3. Despliega los manifiestos de Kubernetes en el orden correcto
4. Configura Ingress para acceder a la aplicación
5. Muestra información de cómo acceder a la aplicación

### 3. Acceder a la Aplicación

Después del despliegue, puedes acceder a la aplicación de varias formas:

#### Usando entradas en /etc/hosts (en tu máquina local)

Agrega estas líneas a tu archivo `/etc/hosts`:

```
MINIKUBE_IP coarlumini.local
MINIKUBE_IP api.coarlumini.local
```

Donde `MINIKUBE_IP` es la IP externa de la VM de Google Cloud.

Luego accede a:
- Frontend: http://coarlumini.local
- API: http://api.coarlumini.local

#### Usando puertos NodePort

También puedes acceder directamente usando los puertos NodePort asignados:
- Frontend: http://IP_VM:FRONTEND_PORT
- Backend: http://IP_VM:BACKEND_PORT

El script de despliegue te mostrará los puertos específicos asignados.

## Administración del Clúster

### Verificar el estado de los pods

```bash
kubectl get pods -n coarlumini
```

### Ver logs de los componentes

```bash
# Logs del backend
kubectl logs -f -l app=coarlumini-backend -n coarlumini

# Logs del frontend
kubectl logs -f -l app=coarlumini-frontend -n coarlumini

# Logs de la base de datos
kubectl logs -f -l app=coarlumini-database -n coarlumini
```

### Reiniciar un despliegue

```bash
kubectl rollout restart deployment/coarlumini-backend -n coarlumini
```

### Acceder a un shell dentro de un contenedor

```bash
# Shell en el backend
kubectl exec -it $(kubectl get pods -n coarlumini -l app=coarlumini-backend -o jsonpath="{.items[0].metadata.name}") -n coarlumini -- /bin/bash

# Shell en la base de datos
kubectl exec -it $(kubectl get pods -n coarlumini -l app=coarlumini-database -o jsonpath="{.items[0].metadata.name}") -n coarlumini -- /bin/bash
```

## Arquitectura

La arquitectura implementada consiste en:

1. **Una VM en Google Cloud** con:
   - 4 vCPUs
   - 16GB de RAM
   - 50GB de disco SSD

2. **Un clúster de Minikube** con:
   - 3 nodos virtuales dentro de la VM
   - Cada nodo ejecuta uno de los componentes (frontend, backend, base de datos)

3. **Tres componentes principales**:
   - **Frontend**: Interfaz de usuario basada en Vue.js
   - **Backend**: API Laravel
   - **Base de datos**: MySQL

4. **Ingress**: Para enrutar el tráfico a los servicios correspondientes

Esta configuración ofrece un entorno Kubernetes completo en una sola VM, lo que reduce costos mientras proporciona la experiencia de un clúster con múltiples nodos.

## Solución de Problemas

### El despliegue falla por falta de recursos

Si Minikube no puede iniciar con 3 nodos por falta de recursos, puedes modificar los parámetros en `install_minikube.sh`:

```bash
# Reduce el número de CPUs y memoria asignados
minikube start --driver=docker --nodes=3 --cpus=1 --memory=2g --disk-size=10g
```

### Imágenes Docker no se encuentran

Si los pods no pueden encontrar las imágenes Docker, verifica que estás usando el entorno Docker de Minikube:

```bash
eval $(minikube docker-env)
docker images  # Verifica que tus imágenes estén presentes
```

### Los PVCs no se provisionan

Si los PVCs no cambian a estado "Bound", verifica que el aprovisionador de almacenamiento de Minikube esté funcionando:

```bash
minikube addons enable storage-provisioner
kubectl get sc  # Verifica que exista una StorageClass predeterminada
```
