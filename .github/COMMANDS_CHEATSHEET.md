# 🚀 Comandos Útiles - GitHub Actions + GKE

Guía rápida de comandos para trabajar con el CI/CD.

---

## 📦 Configuración Inicial (Una sola vez)

```bash
# 1. Ejecutar script de configuración
cd .github/scripts
./setup-gcp-for-github-actions.sh

# 2. Agregar secrets a GitHub
# Ve a: Settings → Secrets and variables → Actions
# (Usa los valores que muestra el script)

# 3. Verificar que el clúster existe
gcloud container clusters list

# 4. Verificar Artifact Registry
gcloud artifacts repositories list
```

---

## 🔍 Monitoreo en Tiempo Real

```bash
# Ver pods en tiempo real
watch kubectl get pods -n coarlumini

# Ver logs del backend (Laravel)
kubectl logs -f -l app=coarlumini-backend -n coarlumini

# Ver logs de la base de datos
kubectl logs -f -l app=coarlumini-database -n coarlumini

# Ver logs del frontend
kubectl logs -f -l app=coarlumini-frontend -n coarlumini

# Ver todos los recursos
kubectl get all -n coarlumini

# Ver eventos recientes
kubectl get events -n coarlumini --sort-by='.lastTimestamp' | head -20
```

---

## 🎯 Estado del Despliegue

```bash
# Ver estado del deployment del backend
kubectl rollout status deployment/coarlumini-backend -n coarlumini

# Ver historial de despliegues
kubectl rollout history deployment/coarlumini-backend -n coarlumini

# Describir un pod específico
POD=$(kubectl get pods -n coarlumini -l app=coarlumini-backend -o jsonpath="{.items[0].metadata.name}")
kubectl describe pod $POD -n coarlumini

# Ver uso de recursos
kubectl top pods -n coarlumini
kubectl top nodes
```

---

## 🔄 Gestión de Despliegues

```bash
# Reiniciar deployment manualmente
kubectl rollout restart deployment/coarlumini-backend -n coarlumini

# Hacer rollback al despliegue anterior
kubectl rollout undo deployment/coarlumini-backend -n coarlumini

# Hacer rollback a una versión específica
kubectl rollout undo deployment/coarlumini-backend -n coarlumini --to-revision=2

# Pausar un rollout
kubectl rollout pause deployment/coarlumini-backend -n coarlumini

# Reanudar un rollout
kubectl rollout resume deployment/coarlumini-backend -n coarlumini
```

---

## 🐛 Debugging

```bash
# Entrar a un pod del backend
POD=$(kubectl get pods -n coarlumini -l app=coarlumini-backend -o jsonpath="{.items[0].metadata.name}")
kubectl exec -it $POD -n coarlumini -- /bin/bash

# Ejecutar comando en el pod sin entrar
kubectl exec $POD -n coarlumini -- php artisan --version

# Ver configuración del deployment
kubectl get deployment coarlumini-backend -n coarlumini -o yaml

# Ver variables de entorno del pod
kubectl exec $POD -n coarlumini -- env

# Verificar conectividad a la base de datos
kubectl exec $POD -n coarlumini -- php artisan tinker --execute="DB::connection()->getPdo();"
```

---

## 🌐 Acceso a la Aplicación

```bash
# Obtener IP del Ingress
kubectl get ingress -n coarlumini

# Obtener IP con formato específico
INGRESS_IP=$(kubectl get ingress -n coarlumini -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')
echo "Frontend: http://$INGRESS_IP"
echo "API: http://$INGRESS_IP/api"

# Ver servicios y sus puertos
kubectl get svc -n coarlumini

# Port-forward para acceso local (útil para debugging)
kubectl port-forward -n coarlumini svc/coarlumini-backend-service 8080:80
# Luego accede a: http://localhost:8080
```

---

## 🔧 Laravel Artisan Commands

```bash
# Variable POD
POD=$(kubectl get pods -n coarlumini -l app=coarlumini-backend -o jsonpath="{.items[0].metadata.name}")

# Ejecutar migraciones
kubectl exec $POD -n coarlumini -- php artisan migrate --force

# Rollback migraciones
kubectl exec $POD -n coarlumini -- php artisan migrate:rollback --force

# Ejecutar seeders
kubectl exec $POD -n coarlumini -- php artisan db:seed --force

# Limpiar caches
kubectl exec $POD -n coarlumini -- php artisan cache:clear
kubectl exec $POD -n coarlumini -- php artisan config:clear
kubectl exec $POD -n coarlumini -- php artisan route:clear
kubectl exec $POD -n coarlumini -- php artisan view:clear

# Optimizar para producción
kubectl exec $POD -n coarlumini -- php artisan config:cache
kubectl exec $POD -n coarlumini -- php artisan route:cache
kubectl exec $POD -n coarlumini -- php artisan view:cache

# Ver rutas
kubectl exec $POD -n coarlumini -- php artisan route:list

# Ejecutar tinker
kubectl exec -it $POD -n coarlumini -- php artisan tinker
```

---

## 🖼️ Gestión de Imágenes Docker

```bash
# Ver imágenes en Artifact Registry
gcloud artifacts docker images list \
  us-central1-docker.pkg.dev/cloudcomputingunsa/coarlumini-images

# Ver tags de una imagen específica
gcloud artifacts docker images list \
  us-central1-docker.pkg.dev/cloudcomputingunsa/coarlumini-images/coarlumini-backend \
  --include-tags

# Eliminar imagen antigua
gcloud artifacts docker images delete \
  us-central1-docker.pkg.dev/cloudcomputingunsa/coarlumini-images/coarlumini-backend:OLD_TAG
```

---

## 📈 Autoescalado (HPA)

```bash
# Ver estado del HPA
kubectl get hpa -n coarlumini

# Describir HPA
kubectl describe hpa coarlumini-backend -n coarlumini

# Editar configuración del HPA
kubectl edit hpa coarlumini-backend -n coarlumini

# Escalar manualmente (sobrescribe HPA temporalmente)
kubectl scale deployment/coarlumini-backend --replicas=5 -n coarlumini
```

---

## 🔒 Gestión de Secrets y ConfigMaps

```bash
# Ver secrets
kubectl get secrets -n coarlumini

# Ver contenido de un secret (decodificado)
kubectl get secret coarlumini-secrets -n coarlumini -o jsonpath='{.data.DB_PASSWORD}' | base64 -d

# Ver ConfigMaps
kubectl get configmaps -n coarlumini

# Editar un ConfigMap
kubectl edit configmap coarlumini-config -n coarlumini

# Recrear pods después de cambiar secrets/configmaps
kubectl rollout restart deployment/coarlumini-backend -n coarlumini
```

---

## 🧪 Testing y Troubleshooting

```bash
# Ejecutar tests de Laravel
kubectl exec $POD -n coarlumini -- php artisan test

# Verificar conectividad entre pods
kubectl exec $POD -n coarlumini -- ping coarlumini-database-service

# Verificar DNS interno
kubectl exec $POD -n coarlumini -- nslookup coarlumini-database-service

# Ver logs del sistema
kubectl logs -n kube-system -l k8s-app=kube-dns

# Probar endpoint de health
curl http://$INGRESS_IP/api/health
```

---

## 🗑️ Limpieza

```bash
# Eliminar todo el namespace (¡CUIDADO!)
kubectl delete namespace coarlumini

# Eliminar solo el backend
kubectl delete deployment coarlumini-backend -n coarlumini

# Eliminar imágenes antiguas del Artifact Registry
# (Script para eliminar imágenes mayores a 30 días)
gcloud artifacts docker images list \
  us-central1-docker.pkg.dev/cloudcomputingunsa/coarlumini-images/coarlumini-backend \
  --filter="createTime<$(date -d '30 days ago' --iso-8601)" \
  --format="value(package)" | \
  xargs -I {} gcloud artifacts docker images delete {} --quiet
```

---

## 📊 Métricas y Performance

```bash
# Instalar metrics-server (si no está)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Ver uso de CPU y memoria de pods
kubectl top pods -n coarlumini

# Ver uso de recursos de nodos
kubectl top nodes

# Ver límites de recursos configurados
kubectl describe pod $POD -n coarlumini | grep -A 5 "Limits\|Requests"
```

---

## 🎯 Comandos de GitHub CLI (opcional)

```bash
# Instalar GitHub CLI
brew install gh  # macOS
# o
sudo apt install gh  # Ubuntu

# Autenticarse
gh auth login

# Ver workflows
gh workflow list

# Ejecutar workflow manualmente
gh workflow run deploy.yml

# Ver runs recientes
gh run list --workflow=deploy.yml

# Ver logs de un run
gh run view --log
```

---

## 🚨 Comandos de Emergencia

```bash
# Si algo sale mal, rollback inmediato
kubectl rollout undo deployment/coarlumini-backend -n coarlumini
kubectl rollout undo deployment/coarlumini-frontend -n coarlumini

# Escalar a 0 (detener la app)
kubectl scale deployment/coarlumini-backend --replicas=0 -n coarlumini

# Reiniciar todo
kubectl rollout restart deployment -n coarlumini

# Ver todos los errores recientes
kubectl get events -n coarlumini --field-selector type=Warning

# Backup de la base de datos (si es urgente)
kubectl exec -n coarlumini -l app=coarlumini-database -- \
  mysqldump -u root -p"$DB_PASSWORD" coarlumini > backup-$(date +%Y%m%d).sql
```

---

**💡 Tip:** Guarda estos comandos en un alias o script para acceso rápido!

```bash
# Agregar a tu ~/.bashrc o ~/.zshrc
alias k='kubectl'
alias kgp='kubectl get pods -n coarlumini'
alias klogs='kubectl logs -f -n coarlumini'
alias kexec='kubectl exec -it -n coarlumini'
```
