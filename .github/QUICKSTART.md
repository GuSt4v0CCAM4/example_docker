# ⚡ Inicio Rápido - CI/CD para Coarlumini

Configura el despliegue automático de tu aplicación Laravel en GKE en **menos de 10 minutos**.

---

## 🎯 Paso 1: Configurar GCP (5 minutos)

```bash
# Clonar el repositorio
git clone <tu-repo>
cd coarlumini

# Ejecutar script de configuración automática
cd .github/scripts
chmod +x setup-gcp-for-github-actions.sh
./setup-gcp-for-github-actions.sh
```

✅ Este script crea:
- Service Account con permisos necesarios
- Key JSON para autenticación
- Artifact Registry para imágenes Docker

📝 **Guarda el output** - lo necesitarás para el siguiente paso.

---

## 🔐 Paso 2: Configurar GitHub Secrets (3 minutos)

1. Ve a tu repositorio en GitHub
2. **Settings** → **Secrets and variables** → **Actions**
3. Click en **"New repository secret"**
4. Agrega estos 6 secrets:

| Secret Name | Obtener valor |
|-------------|---------------|
| `GCP_PROJECT_ID` | Del output del script |
| `GCP_SA_KEY` | Todo el JSON del output |
| `GKE_CLUSTER_NAME` | `coarlumini-cluster` |
| `GKE_ZONE` | `us-central1-a` |
| `GAR_LOCATION` | `us-central1` |
| `GAR_REPOSITORY` | `coarlumini-images` |

💡 **Tip:** El script ya te mostró todos los valores que necesitas.

---

## 🚀 Paso 3: Desplegar (2 minutos)

```bash
# Volver al directorio raíz
cd ../..

# Agregar archivos al repositorio
git add .github/
git commit -m "feat: configurar CI/CD con GitHub Actions"
git push origin main
```

🎉 **¡Listo!** GitHub Actions detectará el push y comenzará el despliegue automáticamente.

---

## 👀 Paso 4: Monitorear el Despliegue

### Desde GitHub:
1. Ve a la pestaña **Actions** en tu repositorio
2. Verás el workflow "Deploy Laravel to GKE" en ejecución
3. Haz click para ver el progreso en tiempo real

### Desde tu terminal:
```bash
# Configurar kubectl (si no lo has hecho)
gcloud container clusters get-credentials coarlumini-cluster \
  --zone=us-central1-a \
  --project=cloudcomputingunsa

# Ver pods en tiempo real
watch kubectl get pods -n coarlumini

# Ver logs del backend
kubectl logs -f -l app=coarlumini-backend -n coarlumini
```

---

## 🌐 Paso 5: Acceder a tu Aplicación

```bash
# Obtener la IP del Ingress
kubectl get ingress -n coarlumini

# O con formato específico
INGRESS_IP=$(kubectl get ingress -n coarlumini -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')
echo "🌐 Frontend: http://$INGRESS_IP"
echo "🔌 API: http://$INGRESS_IP/api"
```

⏳ **Nota:** La IP del Ingress puede tardar 2-5 minutos en asignarse.

---

## ✅ Verificación

Si todo salió bien, deberías ver:

```bash
# Todos los pods corriendo
$ kubectl get pods -n coarlumini
NAME                                   READY   STATUS    RESTARTS   AGE
coarlumini-backend-xxx                 1/1     Running   0          2m
coarlumini-database-xxx                1/1     Running   0          3m
coarlumini-frontend-xxx                1/1     Running   0          2m

# Servicios activos
$ kubectl get svc -n coarlumini
NAME                              TYPE           CLUSTER-IP      EXTERNAL-IP
coarlumini-backend-service        ClusterIP      10.x.x.x        <none>
coarlumini-database-service       ClusterIP      10.x.x.x        <none>
coarlumini-frontend-service       ClusterIP      10.x.x.x        <none>

# Ingress con IP asignada
$ kubectl get ingress -n coarlumini
NAME                  CLASS    HOSTS   ADDRESS         PORTS   AGE
coarlumini-ingress    <none>   *       34.x.x.x        80      5m
```

---

## 🔄 Flujo de Trabajo Continuo

Ahora, cada vez que hagas push a `main` o `develop`:

```bash
# 1. Hacer cambios en tu código
vim app/Http/Controllers/SomeController.php

# 2. Commit y push
git add .
git commit -m "feat: agregar nueva funcionalidad"
git push origin main

# 3. ¡GitHub Actions despliega automáticamente!
# No necesitas hacer nada más 🎉
```

---

## 🐛 Problemas Comunes

### "Workflow failed at authentication step"
```bash
# Verifica que el secret GCP_SA_KEY esté correcto
# Debe ser el JSON COMPLETO, incluyendo {} de inicio y fin
```

### "Cannot find cluster"
```bash
# Verifica que tu clúster GKE existe
gcloud container clusters list

# Si no existe, créalo con OpenTofu primero
```

### "Permission denied to Artifact Registry"
```bash
# Re-ejecuta el script de configuración
cd .github/scripts
./setup-gcp-for-github-actions.sh
```

---

## 📚 Siguientes Pasos

Una vez que tengas el CI/CD funcionando:

1. **Personaliza el workflow:**
   - Edita `.github/workflows/deploy.yml`
   - Agrega tests automatizados
   - Configura notificaciones

2. **Configura ambientes:**
   - Crea workflows separados para staging/production
   - Usa diferentes secrets para cada ambiente

3. **Optimiza:**
   - Implementa cache de Docker layers
   - Configura health checks más robustos
   - Agrega monitoring y alertas

---

## 📖 Documentación Completa

- **Guía detallada:** [DEPLOYMENT_SETUP.md](./DEPLOYMENT_SETUP.md)
- **Comandos útiles:** [COMMANDS_CHEATSHEET.md](./COMMANDS_CHEATSHEET.md)
- **Secrets de ejemplo:** [secrets.example.md](./secrets.example.md)
- **README principal:** [README.md](./README.md)

---

## 🆘 ¿Necesitas Ayuda?

1. **Revisa los logs:**
   ```bash
   kubectl logs -l app=coarlumini-backend -n coarlumini
   ```

2. **Revisa eventos:**
   ```bash
   kubectl get events -n coarlumini --sort-by='.lastTimestamp'
   ```

3. **Consulta la documentación completa:**
   - [DEPLOYMENT_SETUP.md](./DEPLOYMENT_SETUP.md)

---

## 🎉 ¡Felicidades!

Tu pipeline de CI/CD está listo. Ahora puedes:

✅ Desplegar con cada `git push`  
✅ Rollback automático si algo falla  
✅ Monitorear el estado en tiempo real  
✅ Escalar automáticamente con HPA  
✅ Mantener historial de versiones  

**¡Happy Coding! 🚀**