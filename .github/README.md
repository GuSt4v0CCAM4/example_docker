# 🚀 GitHub Actions CI/CD para Coarlumini

Este directorio contiene la configuración de CI/CD para desplegar automáticamente la aplicación Laravel (Coarlumini) en Google Kubernetes Engine (GKE).

## 📂 Estructura

```
.github/
├── workflows/
│   └── deploy.yml                          # Workflow principal de despliegue
├── scripts/
│   └── setup-gcp-for-github-actions.sh     # Script de configuración de GCP
├── DEPLOYMENT_SETUP.md                     # Guía detallada de configuración
└── README.md                               # Este archivo
```

## 🎯 ¿Qué hace el workflow?

El workflow `deploy.yml` se ejecuta automáticamente cuando:
- ✅ Haces push a las ramas `main` o `develop`
- ✅ Creas un Pull Request hacia `main`
- ✅ Lo ejecutas manualmente desde GitHub Actions

### Pasos del workflow:

1. **Checkout del código** - Descarga el código del repositorio
2. **Autenticación en GCP** - Se autentica usando Service Account
3. **Build de imagen Docker** - Construye la imagen del backend Laravel
4. **Push a Artifact Registry** - Sube la imagen etiquetada con el commit SHA
5. **Configurar kubectl** - Obtiene credenciales del clúster GKE
6. **Aplicar manifiestos K8s** - Despliega todos los recursos de Kubernetes
7. **Ejecutar migraciones** - Ejecuta `php artisan migrate` en el pod
8. **Verificar estado** - Muestra el estado del despliegue y la URL

## ⚡ Inicio Rápido

### 1. Configurar GCP (Una sola vez)

Ejecuta el script de configuración:

```bash
cd .github/scripts
./setup-gcp-for-github-actions.sh
```

Este script:
- ✅ Crea el Service Account con permisos necesarios
- ✅ Genera la key JSON para autenticación
- ✅ Crea el Artifact Registry para las imágenes Docker
- ✅ Te muestra los valores para los GitHub Secrets

### 2. Configurar GitHub Secrets

Ve a: **Settings → Secrets and variables → Actions → New repository secret**

Agrega estos secrets:

| Secret | Ejemplo | Descripción |
|--------|---------|-------------|
| `GCP_PROJECT_ID` | `cloudcomputingunsa` | ID de tu proyecto GCP |
| `GCP_SA_KEY` | `{...JSON...}` | Contenido del archivo JSON del Service Account |
| `GKE_CLUSTER_NAME` | `coarlumini-cluster` | Nombre del clúster GKE |
| `GKE_ZONE` | `us-central1-a` | Zona donde está el clúster |
| `GAR_LOCATION` | `us-central1` | Ubicación del Artifact Registry |
| `GAR_REPOSITORY` | `coarlumini-images` | Nombre del repositorio GAR |

### 3. ¡Listo! 🎉

Ahora solo haz push:

```bash
git add .
git commit -m "feat: agregar CI/CD"
git push origin main
```

El workflow se ejecutará automáticamente y desplegará tu aplicación.

## 📊 Monitorear el Despliegue

### Desde GitHub
1. Ve a la pestaña **Actions** en tu repositorio
2. Haz clic en el workflow "Deploy Laravel to GKE"
3. Observa el progreso en tiempo real

### Desde tu terminal
```bash
# Ver pods
kubectl get pods -n coarlumini -w

# Ver logs del backend
kubectl logs -f -l app=coarlumini-backend -n coarlumini

# Ver estado del despliegue
kubectl rollout status deployment/coarlumini-backend -n coarlumini

# Obtener URL de la aplicación
kubectl get ingress -n coarlumini
```

## 🔄 Flujo de Trabajo

```
┌─────────────────────┐
│  git push origin    │
│       main          │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ GitHub Actions      │
│ se ejecuta auto     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Build imagen Docker │
│ Tag: commit-sha     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Push a Artifact     │
│ Registry (GAR)      │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Deploy a GKE        │
│ kubectl apply       │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Ejecutar migraciones│
│ php artisan migrate │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ ✅ App desplegada   │
│ http://IP-INGRESS   │
└─────────────────────┘
```

## 🐛 Troubleshooting

### El workflow falla en "Authenticate to Google Cloud"
- ✅ Verifica que el secret `GCP_SA_KEY` contenga el JSON completo
- ✅ Verifica que el Service Account tenga los roles necesarios

### El workflow falla en "Push Docker image"
- ✅ Verifica que el Artifact Registry exista
- ✅ Verifica que el Service Account tenga rol `artifactregistry.writer`

### El workflow falla en "Get GKE credentials"
- ✅ Verifica que el clúster GKE exista
- ✅ Verifica que el nombre y zona sean correctos
- ✅ Verifica que el Service Account tenga rol `container.developer`

### Los pods no inician después del despliegue
```bash
# Ver logs del pod
kubectl logs -l app=coarlumini-backend -n coarlumini

# Describir el pod para ver eventos
kubectl describe pods -l app=coarlumini-backend -n coarlumini

# Verificar que la imagen existe
gcloud artifacts docker images list \
  us-central1-docker.pkg.dev/cloudcomputingunsa/coarlumini-images
```

## 🔐 Seguridad

### ✅ Buenas prácticas implementadas:

- **Service Account dedicado** - No usa credenciales personales
- **Permisos mínimos** - Solo los roles necesarios
- **Secrets en GitHub** - Las credenciales están cifradas
- **Imágenes etiquetadas** - Cada despliegue tiene un tag único (commit SHA)
- **No hay hardcoded secrets** - Todo se maneja con variables de entorno

### ⚠️ Recomendaciones adicionales:

1. **Rotar keys regularmente** - Regenera las keys del Service Account cada 90 días
2. **Usar Workload Identity** - Para producción, considera usar Workload Identity Federation
3. **Separate environments** - Usa diferentes Service Accounts para staging/production
4. **Audit logs** - Habilita logs de auditoría en GCP

## 📚 Documentación Adicional

- [Guía completa de configuración](./DEPLOYMENT_SETUP.md)
- [Workflow principal](./workflows/deploy.yml)
- [Script de configuración](./scripts/setup-gcp-for-github-actions.sh)

## 🆘 Soporte

Si tienes problemas:

1. **Lee la documentación completa**: [`DEPLOYMENT_SETUP.md`](./DEPLOYMENT_SETUP.md)
2. **Revisa los logs del workflow**: GitHub Actions → [Nombre del workflow] → View logs
3. **Verifica el estado del clúster**: `kubectl get all -n coarlumini`
4. **Revisa los eventos**: `kubectl get events -n coarlumini --sort-by='.lastTimestamp'`

## 🎯 Próximos Pasos

Después de configurar el CI/CD, considera:

- [ ] Configurar notificaciones de Slack/Discord para los despliegues
- [ ] Agregar tests automatizados antes del despliegue
- [ ] Configurar ambientes separados (staging/production)
- [ ] Implementar rollback automático en caso de fallo
- [ ] Agregar health checks más robustos
- [ ] Configurar alertas de monitoreo

---

**¿Preguntas?** Revisa la [guía completa de configuración](./DEPLOYMENT_SETUP.md) 📖