#!/bin/bash

# Script para configurar GCP para GitHub Actions
# Este script crea el Service Account y Artifact Registry necesarios

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Configuración por defecto
PROJECT_ID="${GCP_PROJECT_ID:-cloudcomputingunsa}"
SA_NAME="github-actions-deployer"
GAR_LOCATION="us-central1"
GAR_REPOSITORY="coarlumini-images"

echo "════════════════════════════════════════════════════════════"
echo "🚀 Configuración de GCP para GitHub Actions"
echo "════════════════════════════════════════════════════════════"
echo ""

# Verificar gcloud
if ! command -v gcloud &> /dev/null; then
    print_error "gcloud CLI no está instalado"
    exit 1
fi

# Configurar proyecto
print_info "Configurando proyecto: $PROJECT_ID"
gcloud config set project $PROJECT_ID

# Verificar autenticación
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q '@'; then
    print_error "No estás autenticado en gcloud"
    echo "Ejecuta: gcloud auth login"
    exit 1
fi

print_success "Autenticado correctamente"

# Habilitar APIs
print_info "Habilitando APIs necesarias..."
gcloud services enable iamcredentials.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable storage.googleapis.com
print_success "APIs habilitadas"

# Crear Service Account
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

print_info "Creando Service Account: $SA_EMAIL"
if gcloud iam service-accounts describe $SA_EMAIL &>/dev/null; then
    print_warning "Service Account ya existe"
else
    gcloud iam service-accounts create $SA_NAME \
        --display-name="GitHub Actions Deployer" \
        --project=$PROJECT_ID
    print_success "Service Account creado"
fi

# Asignar roles
print_info "Asignando roles al Service Account..."

ROLES=(
    "roles/container.developer"
    "roles/artifactregistry.writer"
    "roles/storage.admin"
)

for role in "${ROLES[@]}"; do
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:${SA_EMAIL}" \
        --role="$role" \
        --condition=None \
        > /dev/null 2>&1
    print_success "Rol asignado: $role"
done

# Crear key JSON
KEY_FILE="github-actions-key.json"
print_info "Creando key JSON..."

if [ -f "$KEY_FILE" ]; then
    print_warning "Key file ya existe. ¿Deseas sobrescribirla? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        print_info "Usando key existente"
    else
        gcloud iam service-accounts keys create $KEY_FILE \
            --iam-account=$SA_EMAIL
        print_success "Nueva key creada"
    fi
else
    gcloud iam service-accounts keys create $KEY_FILE \
        --iam-account=$SA_EMAIL
    print_success "Key JSON creada: $KEY_FILE"
fi

# Crear Artifact Registry
print_info "Creando Artifact Registry..."

if gcloud artifacts repositories describe $GAR_REPOSITORY --location=$GAR_LOCATION &>/dev/null; then
    print_warning "Artifact Registry ya existe"
else
    gcloud artifacts repositories create $GAR_REPOSITORY \
        --repository-format=docker \
        --location=$GAR_LOCATION \
        --description="Docker images for Coarlumini" \
        --project=$PROJECT_ID
    print_success "Artifact Registry creado"
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "✅ CONFIGURACIÓN COMPLETADA"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "📝 Agrega estos GitHub Secrets en tu repositorio:"
echo "   Settings → Secrets and variables → Actions"
echo ""
echo "┌────────────────────────────────────────────────────────────┐"
echo "│ Secret Name          │ Valor                               │"
echo "├────────────────────────────────────────────────────────────┤"
echo "│ GCP_PROJECT_ID       │ $PROJECT_ID"
echo "│ GKE_CLUSTER_NAME     │ coarlumini-cluster"
echo "│ GKE_ZONE             │ us-central1-a"
echo "│ GAR_LOCATION         │ $GAR_LOCATION"
echo "│ GAR_REPOSITORY       │ $GAR_REPOSITORY"
echo "│ GCP_SA_KEY           │ (ver abajo)"
echo "└────────────────────────────────────────────────────────────┘"
echo ""
echo "🔑 Contenido de GCP_SA_KEY:"
echo "════════════════════════════════════════════════════════════"
cat $KEY_FILE
echo "════════════════════════════════════════════════════════════"
echo ""
print_warning "¡IMPORTANTE! Guarda esta key de forma segura"
print_warning "Nunca la subas a Git ni la compartas públicamente"
echo ""
print_info "Key guardada en: $KEY_FILE"
print_info "Puedes eliminarla después de configurar GitHub Secrets"
echo ""
