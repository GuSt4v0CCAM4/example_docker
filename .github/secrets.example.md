# 🔐 GitHub Secrets - Ejemplo de Configuración

Este archivo contiene ejemplos de los secrets que necesitas configurar en GitHub para que el workflow de CI/CD funcione correctamente.

## 📍 Ubicación en GitHub

1. Ve a tu repositorio en GitHub
2. **Settings** → **Secrets and variables** → **Actions**
3. Click en **"New repository secret"**
4. Agrega cada uno de los siguientes secrets

---

## 🔑 Secrets Requeridos

### `GCP_PROJECT_ID`
**Descripción:** ID de tu proyecto en Google Cloud Platform  
**Ejemplo:**
```
cloudcomputingunsa
```

**Cómo obtenerlo:**
```bash
gcloud config get-value project
# O
gcloud projects list --format="value(projectId)"
```

---

### `GCP_SA_KEY`
**Descripción:** Contenido completo del archivo JSON del Service Account  
**Ejemplo:**
```json
{
  "type": "service_account",
  "project_id": "cloudcomputingunsa",
  "private_key_id": "abc123def456...",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkq...\n-----END PRIVATE KEY-----\n",
  "client_email": "github-actions-deployer@cloudcomputingunsa.iam.gserviceaccount.com",
  "client_id": "123456789012345678901",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/github-actions-deployer%40cloudcomputingunsa.iam.gserviceaccount.com"
}
```

**Cómo obtenerlo:**
```bash
# Usando el script de configuración
./github/scripts/setup-gcp-for-github-actions.sh

# O manualmente
gcloud iam service-accounts keys create github-actions-key.json \
  --iam-account=github-actions-deployer@cloudcomputingunsa.iam.gserviceaccount.com

# Mostrar el contenido
cat github-actions-key.json
```

⚠️ **IMPORTANTE:** Copia TODO el contenido del archivo JSON, incluyendo las llaves `{}` de inicio y fin.

---

### `GKE_CLUSTER_NAME`
**Descripción:** Nombre del clúster de Kubernetes en GKE  
**Ejemplo:**
```
coarlumini-cluster
```

**Cómo obtenerlo:**
```bash
gcloud container clusters list --format="value(name)"
```

---

### `GKE_ZONE`
**Descripción:** Zona donde está ubicado el clúster GKE  
**Ejemplo:**
```
us-central1-a
```

**Otras opciones comunes:**
- `us-central1-b`
- `us-east1-b`
- `europe-west1-b`

**Cómo obtenerlo:**
```bash
gcloud container clusters list --format="value(location)"
```

---

### `GAR_LOCATION`
**Descripción:** Región donde está el Google Artifact Registry  
**Ejemplo:**
```
us-central1
```

**Otras opciones comunes:**
- `us-east1`
- `europe-west1`
- `asia-southeast1`

**Cómo obtenerlo:**
```bash
gcloud artifacts repositories list --format="value(location)"
```

---

### `GAR_REPOSITORY`
**Descripción:** Nombre del repositorio en Google Artifact Registry  
**Ejemplo:**
```
coarlumini-images
```

**Cómo obtenerlo:**
```bash
gcloud artifacts repositories list --format="value(repository)"
```

---

## 📋 Checklist de Configuración

Marca cada secret a medida que lo configures:

- [ ] `GCP_PROJECT_ID` - ID del proyecto GCP
- [ ] `GCP_SA_KEY` - JSON completo del Service Account
- [ ] `GKE_CLUSTER_NAME` - Nombre del clúster
- [ ] `GKE_ZONE` - Zona del clúster
- [ ] `GAR_LOCATION` - Región del Artifact Registry
- [ ] `GAR_REPOSITORY` - Nombre del repositorio de imágenes

---

## ✅ Verificar Configuración

Después de agregar todos los secrets, verifica que estén configurados correctamente:

1. Ve a **Settings** → **Secrets and variables** → **Actions**
2. Deberías ver los 6 secrets listados (el contenido está oculto por seguridad)
3. Los nombres deben coincidir EXACTAMENTE con los de arriba (case-sensitive)

---

## 🧪 Probar el Workflow

Una vez configurados todos los secrets:

```bash
# Opción 1: Push a main/develop
git add .
git commit -m "test: probar CI/CD"
git push origin main

# Opción 2: Trigger manual
# Ve a Actions → Deploy Laravel to GKE → Run workflow
```

---

## 🔒 Seguridad

### ✅ Buenas prácticas:

- **NUNCA** subas el archivo `github-actions-key.json` a Git
- **NUNCA** compartas públicamente los secrets
- **Agrega** `*.json` al `.gitignore`
- **Rota** las keys del Service Account cada 90 días
- **Usa** diferentes Service Accounts para staging/production

### 📝 Agregar al .gitignore:

```bash
echo "github-actions-key.json" >> .gitignore
echo "*-key.json" >> .gitignore
git add .gitignore
git commit -m "chore: agregar keys a gitignore"
```

---

## 🆘 Troubleshooting

### Error: "Invalid credentials"
- Verifica que el JSON esté completo (debe empezar con `{` y terminar con `}`)
- Verifica que no haya espacios o saltos de línea adicionales al pegar

### Error: "Permission denied"
- Verifica que el Service Account tenga los roles necesarios:
  - `roles/container.developer`
  - `roles/artifactregistry.writer`
  - `roles/storage.admin`

### Error: "Cluster not found"
- Verifica que el nombre del clúster sea correcto
- Verifica que la zona coincida con la ubicación del clúster

---

## 📚 Recursos Adicionales

- [GitHub Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Google Cloud Service Accounts](https://cloud.google.com/iam/docs/service-accounts)
- [GKE Authentication](https://cloud.google.com/kubernetes-engine/docs/how-to/api-server-authentication)

---

## 💡 Valores de Ejemplo Completos

Para tu proyecto **Coarlumini**:

```yaml
GCP_PROJECT_ID: "cloudcomputingunsa"
GCP_SA_KEY: "{...contenido del JSON...}"
GKE_CLUSTER_NAME: "coarlumini-cluster"
GKE_ZONE: "us-central1-a"
GAR_LOCATION: "us-central1"
GAR_REPOSITORY: "coarlumini-images"
```

---

**🎯 Una vez configurado, ¡tu CI/CD estará listo para funcionar!**