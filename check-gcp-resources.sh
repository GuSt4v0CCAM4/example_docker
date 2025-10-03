#!/bin/bash

# Script para verificar cuotas y permisos en Google Cloud Platform
# Autor: Coarlumini Team
# Fecha: 2025-10-02

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

# Configuración
PROJECT_ID="cloudcomputingunsa"
ZONE="us-central1-a"
REGION=${ZONE%-*}  # Extraer la región de la zona (us-central1-a -> us-central1)

# Verificar gcloud
if ! command -v gcloud &> /dev/null; then
    print_error "gcloud no está instalado. Por favor, instálalo primero."
    exit 1
fi

# Verificar autenticación
print_info "Verificando autenticación en GCP..."
AUTH_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null)
if [ -z "$AUTH_ACCOUNT" ]; then
    print_error "No estás autenticado en GCP. Por favor, ejecuta 'gcloud auth login'"
    exit 1
else
    print_success "Autenticado como: $AUTH_ACCOUNT"
fi

# Configurar proyecto
print_info "Configurando proyecto: $PROJECT_ID"
gcloud config set project $PROJECT_ID
print_success "Proyecto configurado: $PROJECT_ID"

# Verificar estado del proyecto
print_info "Verificando estado del proyecto..."
PROJECT_STATE=$(gcloud projects describe $PROJECT_ID --format="value(lifecycleState)" 2>/dev/null)
if [ "$PROJECT_STATE" != "ACTIVE" ]; then
    print_error "El proyecto no está activo. Estado: $PROJECT_STATE"
    exit 1
else
    print_success "Proyecto activo: $PROJECT_ID"
fi

# Verificar facturación
print_info "Verificando estado de facturación..."
BILLING_ENABLED=$(gcloud billing projects describe $PROJECT_ID --format="value(billingEnabled)" 2>/dev/null)
if [ "$BILLING_ENABLED" != "True" ]; then
    print_warning "El proyecto no tiene facturación habilitada. Esto puede impedir la creación de recursos."
    print_info "Puedes habilitar la facturación en: https://console.cloud.google.com/billing/linkedaccount?project=$PROJECT_ID"
else
    print_success "Facturación habilitada para el proyecto"
fi

# Verificar APIs habilitadas
print_info "Verificando APIs necesarias..."
COMPUTE_API=$(gcloud services list --filter="name:compute.googleapis.com" --format="value(state)" 2>/dev/null)
if [ "$COMPUTE_API" != "ENABLED" ]; then
    print_warning "Compute Engine API no está habilitada"
    print_info "Habilitando Compute Engine API..."
    gcloud services enable compute.googleapis.com
else
    print_success "Compute Engine API está habilitada"
fi

CONTAINER_API=$(gcloud services list --filter="name:container.googleapis.com" --format="value(state)" 2>/dev/null)
if [ "$CONTAINER_API" != "ENABLED" ]; then
    print_warning "Kubernetes Engine API no está habilitada"
    print_info "Habilitando Kubernetes Engine API..."
    gcloud services enable container.googleapis.com
else
    print_success "Kubernetes Engine API está habilitada"
fi

REGISTRY_API=$(gcloud services list --filter="name:containerregistry.googleapis.com" --format="value(state)" 2>/dev/null)
if [ "$REGISTRY_API" != "ENABLED" ]; then
    print_warning "Container Registry API no está habilitada"
    print_info "Habilitando Container Registry API..."
    gcloud services enable containerregistry.googleapis.com
else
    print_success "Container Registry API está habilitada"
fi

ARTIFACT_API=$(gcloud services list --filter="name:artifactregistry.googleapis.com" --format="value(state)" 2>/dev/null)
if [ "$ARTIFACT_API" != "ENABLED" ]; then
    print_warning "Artifact Registry API no está habilitada"
    print_info "Habilitando Artifact Registry API..."
    gcloud services enable artifactregistry.googleapis.com
else
    print_success "Artifact Registry API está habilitada"
fi

# Verificar cuotas de GKE
print_info "Verificando cuotas para GKE en $REGION..."
CPU_QUOTA=$(gcloud compute regions describe $REGION --format="value(quotas.metric=='CPUS'.limit)")
CPU_USAGE=$(gcloud compute regions describe $REGION --format="value(quotas.metric=='CPUS'.usage)")
print_info "CPUs - Límite: $CPU_QUOTA, Uso: $CPU_USAGE"

IN_USE_ADDR_QUOTA=$(gcloud compute regions describe $REGION --format="value(quotas.metric=='IN_USE_ADDRESSES'.limit)")
IN_USE_ADDR_USAGE=$(gcloud compute regions describe $REGION --format="value(quotas.metric=='IN_USE_ADDRESSES'.usage)")
print_info "Direcciones en uso - Límite: $IN_USE_ADDR_QUOTA, Uso: $IN_USE_ADDR_USAGE"

SSD_QUOTA=$(gcloud compute regions describe $REGION --format="value(quotas.metric=='SSD_TOTAL_GB'.limit)")
SSD_USAGE=$(gcloud compute regions describe $REGION --format="value(quotas.metric=='SSD_TOTAL_GB'.usage)")
print_info "SSD (GB) - Límite: $SSD_QUOTA, Uso: $SSD_USAGE"

if (( $(echo "$SSD_QUOTA < 30" | bc -l) )); then
    print_warning "La cuota de SSD puede ser insuficiente para un clúster de GKE"
fi

if (( $(echo "$CPU_QUOTA < 6" | bc -l) )); then
    print_warning "La cuota de CPUs puede ser insuficiente para un clúster de GKE"
fi

# Verificar permisos
print_info "Verificando permisos para GKE..."
IAM_ROLES=$(gcloud projects get-iam-policy $PROJECT_ID --format="value(bindings.role)" 2>/dev/null | grep -E "roles/container|roles/compute|roles/storage")
if [ -z "$IAM_ROLES" ]; then
    print_warning "No se encontraron roles relacionados con GKE, Compute o Storage"
    print_info "Asegúrate de tener los roles necesarios: roles/container.admin, roles/compute.admin, roles/storage.admin"
else
    print_success "Roles encontrados: $(echo $IAM_ROLES | tr '\n' ' ')"
fi

# Intentar crear un clúster mínimo
print_info "Intentando crear un clúster GKE mínimo para verificar permisos..."
TEST_CLUSTER_NAME="test-cluster-$(date +%s)"
gcloud container clusters create $TEST_CLUSTER_NAME \
    --num-nodes=1 \
    --machine-type=e2-small \
    --disk-size=10GB \
    --disk-type=pd-standard \
    --no-enable-cloud-logging \
    --no-enable-cloud-monitoring \
    --zone=$ZONE \
    --quiet 2>&1 | tee cluster_creation.log

if grep -q "ERROR" cluster_creation.log; then
    print_error "Error al crear el clúster de prueba. Detalles:"
    cat cluster_creation.log | grep -A 5 "ERROR"

    # Buscar mensajes específicos de error
    if grep -q "quota" cluster_creation.log; then
        print_warning "Problema detectado: Cuotas insuficientes"
        print_info "Visita: https://console.cloud.google.com/iam-admin/quotas?project=$PROJECT_ID"
    fi

    if grep -q "permission" cluster_creation.log; then
        print_warning "Problema detectado: Permisos insuficientes"
        print_info "Visita: https://console.cloud.google.com/iam-admin/iam?project=$PROJECT_ID"
    fi

    if grep -q "billing" cluster_creation.log; then
        print_warning "Problema detectado: Problemas de facturación"
        print_info "Visita: https://console.cloud.google.com/billing/linkedaccount?project=$PROJECT_ID"
    fi
else
    print_success "Clúster de prueba creado correctamente"
    print_info "Eliminando clúster de prueba..."
    gcloud container clusters delete $TEST_CLUSTER_NAME --zone=$ZONE --quiet
    print_success "Clúster de prueba eliminado correctamente"
fi

rm -f cluster_creation.log

# Intentar crear un bucket de prueba en GCS
print_info "Intentando crear un bucket GCS para verificar permisos..."
TEST_BUCKET_NAME="$PROJECT_ID-test-$(date +%s)"
gcloud storage buckets create gs://$TEST_BUCKET_NAME --location=$REGION 2>&1 | tee bucket_creation.log

if grep -q "ERROR" bucket_creation.log; then
    print_error "Error al crear el bucket de prueba. Detal
