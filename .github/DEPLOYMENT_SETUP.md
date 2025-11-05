# 🚀 Configuración de CI/CD con GitHub Actions para GKE

Esta guía te ayudará a configurar el workflow de GitHub Actions para desplegar automáticamente tu aplicación Laravel en Google Kubernetes Engine (GKE).

## 📋 Prerrequisitos

1. **Clúster GKE ya creado** (mediante OpenTofu u otro método)
2. **Google Artifact Registry (GAR) configurado**
3. **Service Account de GCP con permisos necesarios**

---

## 🔐 Paso 1: Crear Service Account en GCP

```bash
# Configurar variables
export PROJECT_ID="cloudcomputingunsa"
export SA_NAME="github-actions-deployer"
export SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Crear Service Account
gcloud iam service-accounts create $SA_NAME \
    --display-name="GitHub Actions Deployer" \
    --project=$PROJECT_ID

# Asignar roles necesarios
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/container.developer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/artifactregistry.writer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/storage.admin"

# Crear y descargar la key JSON
gcloud iam service-accounts keys create github-actions-key.json \
    --iam-account=$SA_EMAIL

# Mostrar el contenido (lo usarás en GitHub Secrets)
cat github-actions-key.json
```

---

## 🗂️ Paso 2: Crear Google Artifact Registry

```bash
# Configurar variables
export GAR_LOCATION="us-central1"
export GAR_REPOSITORY="coarlumini-images"

# Crear el repositorio
gcloud artifacts repositories create $GAR_REPOSITORY \
    --repository-format=docker \
    --location=$GAR_LOCATION \
    --description="Docker images for Coarlumini" \
    --project=$PROJECT_ID

# Verificar
gcloud artifacts repositories list --project=$PROJECT_ID
```

---

## 🔑 Paso 3: Configurar GitHub Secrets

Ve a tu repositorio en GitHub:
**Settings → Secrets and variables → Actions → New repository secret**

Agrega los siguientes secrets:

| Secret Name | Valor | Descripción |
|-------------|-------|-------------|
| `GCP_PROJECT_ID` | `cloudcomputingunsa` | ID del proyecto de GCP |
| `GCP_SA_KEY` | `{contenido de github-actions-key.json}` | Contenido completo del archivo JSON |
| `GKE_CLUSTER_NAME` | `coarlumini-cluster` | Nombre de tu clúster GKE |
| `GKE_ZONE` | `us-central1-a` | Zona donde está el clúster |
| `GAR_LOCATION` | `us-central1` | Ubicación de Artifact Registry |
| `GAR_REPOSITORY` | `coarlumini-images` | Nombre del repositorio en GAR |

### 📝 Ejemplo de cómo obtener cada valor:

```bash
# GCP_PROJECT_ID
echo $PROJECT_ID

# GCP_SA_KEY (copiar TODO el contenido)
cat github-actions-key.json

# GKE_CLUSTER_NAME
gcloud container clusters list --format="value(name)"

# GKE_ZONE
gcloud container clusters list --format="value(location)"

# GAR_LOCATION
gcloud artifacts repositories list --format="value(location)" | head -1

# GAR_REPOSITORY
gcloud artifacts repositories list --format="value(repository)" | head -1
```

---

## 🛠️ Paso 4: Actualizar Manifiestos de Kubernetes

Asegúrate de que tu `k8s/06-backend-deployment.yaml` use la ruta correcta de GAR:

```yaml
# Antes (GCR - Container Registry viejo)
image: gcr.io/cloudcomputingunsa/coarlumini-backend:latest

# Después (GAR - Artifact Registry)
image: us-central1-docker.pkg.dev/cloudcomputingunsa/coarlumini-images/coarlumini-backend:latest
```

**El workflow automáticamente reemplazará la imagen con el commit SHA.**

---

## 🚀 Paso 5: Probar el Workflow

### Opción A: Push a main/develop

```bash
git add .
git commit -m "feat: configurar CI/CD con GitHub Actions"
git push origin main
```

### Opción B: Trigger manual

1. Ve a tu repositorio en GitHub
2. **Actions → Deploy Laravel to GKE → Run workflow**
3. Selecciona la branch y haz clic en **Run workflow**

---

## 📊 Monitorear el Despliegue

### Desde GitHub

1. Ve a **Actions** en tu repositorio
2. Haz clic en el workflow en ejecución
3. Observa cada paso del job `deploy-laravel`

### Desde tu terminal

```bash
# Ver pods en tiempo real
watch kubectl get pods -n coarlumini

# Ver logs del backend
kubectl logs -f -l app=coarlumini-backend -n coarlumini

# Ver estado del rollout
kubectl rollout status deployment/coarlumini-backend -n coarlumini

# Ver eventos
kubectl get events -n coarlumini --sort-by='.lastTimestamp'
```

---

## 🔍 Verificar el Despliegue

### Obtener la IP de la aplicación

```bash
# Obtener IP del Ingress
kubectl get ingress -n coarlumini

# O con formato específico
kubectl get ingress -n coarlumini -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}'
```

### Probar endpoints

```bash
# Obtener IP
export APP_IP=$(kubectl get ingress -n coarlumini -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')

# Probar frontend
curl http://$APP_IP

# Probar API
curl http://$APP_IP/api

# Probar health check (si lo tienes configurado)
curl http://$APP_IP/api/health
```

---

## 🐛 Troubleshooting

### Error: "Cannot connect to GKE cluster"

```bash
# Verificar que el clúster existe
gcloud container clusters list

# Verificar permisos del Service Account
gcloud projects get-iam-policy $PROJECT_ID \
    --flatten="bindings[].members" \
    --filter="bindings.members:serviceAccount:$SA_EMAIL"
```

### Error: "Permission denied to push to Artifact Registry"

```bash
# Verificar que el repositorio existe
gcloud artifacts repositories list

# Dar permisos al Service Account
gcloud artifacts repositories add-iam-policy-binding $GAR_REPOSITORY \
    --location=$GAR_LOCATION \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/artifactregistry.writer"
```

### Error: "Pods not starting"

```bash
# Ver logs del pod
kubectl logs -l app=coarlumini-backend -n coarlumini

# Describir el pod para ver eventos
kubectl describe pods -l app=coarlumini-backend -n coarlumini

# Verificar que la imagen existe en GAR
gcloud artifacts docker images list $GAR_LOCATION-docker.pkg.dev/$PROJECT_ID/$GAR_REPOSITORY
```

### Error: "Migrations failed"

```bash
# Verificar que la base de datos está corriendo
kubectl get pods -n coarlumini | grep database

# Ver logs de la base de datos
kubectl logs -l app=coarlumini-database -n coarlumini

# Ejecutar migraciones manualmente
POD=$(kubectl get pods -n coarlumini -l app=coarlumini-backend -o jsonpath="{.items[0].metadata.name}")
kubectl exec -n coarlumini $POD -- php artisan migrate --force
```

---

## 🎯 Flujo de Trabajo Completo

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. Developer hace push a main/develop                           │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. GitHub Actions se dispara automáticamente                    │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. Checkout del código + Autenticación en GCP                   │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. Build de la imagen Docker con tag del commit SHA             │
│    Ejemplo: coarlumini-backend:a1b2c3d                          │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. Push de la imagen a Google Artifact Registry                 │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6. Obtener credenciales del clúster GKE                         │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│ 7. Actualizar manifiestos YAML con la nueva imagen              │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│ 8. Aplicar todos los manifiestos de Kubernetes (kubectl apply)  │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│ 9. Forzar rollout del deployment del backend                    │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│ 10. Ejecutar migraciones de Laravel dentro del pod              │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│ 11. Verificar estado y mostrar URL de acceso                    │
│     ✅ Aplicación desplegada en http://IP_DEL_INGRESS           │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Rollback (Volver a una versión anterior)

Si algo sale mal, puedes hacer rollback:

```bash
# Ver historial de despliegues
kubectl rollout history deployment/coarlumini-backend -n coarlumini

# Volver a la versión anterior
kubectl rollout undo deployment/coarlumini-backend -n coarlumini

# Volver a una revisión específica
kubectl rollout undo deployment/coarlumini-backend -n coarlumini --to-revision=2

# Ver estado del rollback
kubectl rollout status deployment/coarlumini-backend -n coarlumini
```

---

## 📚 Referencias

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Google Cloud GitHub Actions](https://github.com/google-github-actions)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [Laravel Deployment Guide](https://laravel.com/docs/deployment)

---

## ✅ Checklist de Configuración

- [ ] Service Account creado en GCP
- [ ] Roles asignados al Service Account
- [ ] Key JSON del Service Account descargada
- [ ] Artifact Registry creado
- [ ] Todos los GitHub Secrets configurados
- [ ] Manifiestos de Kubernetes actualizados con rutas de GAR
- [ ] Workflow de GitHub Actions agregado al repositorio
- [ ] Push realizado y workflow ejecutado exitosamente
- [ ] Aplicación accesible desde el navegador

---

## 💡 Tips Adicionales

### Ambientes separados (staging/production)

Puedes crear workflows separados para diferentes ambientes:

```yaml
# .github/workflows/deploy-staging.yml
on:
  push:
    branches:
      - develop

# .github/workflows/deploy-production.yml
on:
  push:
    branches:
      - main
```

### Notificaciones de Slack/Discord

Agrega un step al final del workflow:

```yaml
- name: Notify Slack
  if: always()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

### Cache de Docker layers

Para acelerar el build:

```yaml
- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v3

- name: Build and push
  uses: docker/build-push-action@v5
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

---

**¡Tu CI/CD está listo! 🎉** Ahora cada push a `main` o `develop` desplegará automáticamente tu aplicación Laravel en GKE.