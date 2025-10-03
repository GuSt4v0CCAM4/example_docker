#!/bin/bash

# Script para compilar y empaquetar la aplicación Coarlumini
# Este script construirá las imágenes Docker para el backend, frontend y base de datos
# y las subirá al Container Registry de Google Cloud

# Configuración de colores para la salida
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

# Verificar dependencias
verify_dependencies() {
    print_info "Verificando dependencias..."

    if ! command -v docker &> /dev/null; then
        print_error "Docker no está instalado. Por favor, instálalo primero."
        exit 1
    fi

    if ! command -v gcloud &> /dev/null; then
        print_warning "gcloud no está instalado. No se podrán subir las imágenes a Google Container Registry."
        USE_GCR=false
    else
        USE_GCR=true
    fi

    if $USE_GCR; then
        if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q '@'; then
            print_warning "No estás autenticado en gcloud. Por favor, ejecuta 'gcloud auth login'"
            USE_GCR=false
        fi
    fi
}

# Solicitar información del proyecto
project_info() {
    if $USE_GCR; then
        PROJECT_ID="cloudcomputingunsa"

        # Verificar si el proyecto existe
        if ! gcloud projects describe $PROJECT_ID &> /dev/null; then
            print_error "El proyecto $PROJECT_ID no existe o no tienes acceso a él."
            print_info "Asegúrate de tener permisos en el proyecto y estar autenticado con 'gcloud auth login'."
            exit 1
        fi

        # Configurar gcloud
        gcloud config set project $PROJECT_ID
        print_success "Proyecto configurado: $PROJECT_ID"

        # Configurar Docker para usar gcloud como credencial helper
        gcloud auth configure-docker
    else
        print_info "No se usará Google Container Registry. Las imágenes se construirán localmente."
    fi
}

# Construir imagen de la base de datos
build_database_image() {
    print_info "Construyendo imagen de la base de datos..."

    # Verificar si existe Dockerfile para la base de datos
    if [ ! -f "../database/Dockerfile" ]; then
        print_warning "No se encontró Dockerfile para la base de datos. Creando uno..."

        # Crear directorio si no existe
        mkdir -p ../database/init-scripts

        # Crear Dockerfile para MySQL
        cat > ../database/Dockerfile << EOF
FROM mysql:8.0

# Configuración personalizada de MySQL
COPY my.cnf /etc/mysql/conf.d/

# Agregar scripts de inicialización
COPY init-scripts/ /docker-entrypoint-initdb.d/

# Configuración personalizada
ENV MYSQL_ROOT_HOST="%"

# Health check para el contenedor
HEALTHCHECK --interval=5s --timeout=5s --retries=3 CMD mysqladmin ping -h localhost

# Comando por defecto
CMD ["mysqld"]
EOF

        # Crear archivo de configuración MySQL
        cat > ../database/my.cnf << EOF
[mysqld]
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
default-authentication-plugin = mysql_native_password
max_connections = 1000
innodb_buffer_pool_size = 256M

[mysql]
default-character-set = utf8mb4

[client]
default-character-set = utf8mb4
EOF
    fi

    # Construir imagen
    if $USE_GCR; then
        DB_IMAGE="gcr.io/${PROJECT_ID}/coarlumini-database:latest"
        docker build -t $DB_IMAGE ../database/
        print_info "Subiendo imagen de la base de datos a Google Container Registry..."
        docker push $DB_IMAGE
    else
        docker build -t coarlumini-database:latest ../database/
    fi

    print_success "Imagen de la base de datos construida exitosamente."
}

# Construir imagen del backend
build_backend_image() {
    print_info "Construyendo imagen del backend..."

    # Crear Dockerfile para Laravel si no existe
    if [ ! -f "../Dockerfile" ]; then
        print_warning "No se encontró Dockerfile para el backend. Creando uno..."

        cat > ../Dockerfile << EOF
FROM php:8.1-apache

# Instalar dependencias
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    zip \
    unzip \
    curl \
    git

# Instalar extensiones PHP
RUN docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd zip

# Instalar Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Configurar Apache
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf
RUN a2enmod rewrite

# Directorio de trabajo
WORKDIR /var/www/html

# Copiar archivos de la aplicación
COPY . .

# Instalar dependencias
RUN composer install --no-dev --optimize-autoloader

# Permisos de directorios
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

# Exponer puerto
EXPOSE 80

# Script de inicio
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["docker-entrypoint.sh"]

# Comando para iniciar Apache
CMD ["apache2-foreground"]
EOF

        # Crear script de entrada para Docker
        cat > ../docker-entrypoint.sh << 'EOF'
#!/bin/sh
set -e

# Verificar si tenemos que esperar a que la base de datos esté lista
if [ -n "$DB_HOST" ]; then
    echo "Esperando a que la base de datos esté disponible..."

    TIMEOUT=60
    COUNT=0
    until php -r "try { new PDO('mysql:host=$DB_HOST', '$DB_USERNAME', '$DB_PASSWORD'); echo \"Connection successful\n\"; } catch (\Exception \$e) { echo \"Error: \" . \$e->getMessage() . \"\n\"; exit(1); }" > /dev/null 2>&1; do
        echo "."
        sleep 1
        COUNT=$((COUNT+1))
        if [ $COUNT -eq $TIMEOUT ]; then
            echo "Error: La conexión a la base de datos no pudo establecerse después de $TIMEOUT segundos."
            exit 1
        fi
    done
fi

# Generar clave de la aplicación si no existe
if [ -z "$APP_KEY" ]; then
    echo "Generando clave de aplicación Laravel..."
    php artisan key:generate
fi

# Ejecutar migraciones si es necesario
if [ "$RUN_MIGRATIONS" = "true" ]; then
    echo "Ejecutando migraciones de la base de datos..."
    php artisan migrate --force
fi

# Optimizar la aplicación para producción
if [ "$APP_ENV" = "production" ]; then
    echo "Optimizando para producción..."
    php artisan config:cache
    php artisan route:cache
    php artisan view:cache
fi

# Crear endpoint de salud para Kubernetes
if [ ! -f "routes/api.php.original" ]; then
    cp routes/api.php routes/api.php.original
    echo "
Route::get('/health', function () {
    return response()->json(['status' => 'ok', 'message' => 'API is healthy']);
});" >> routes/api.php
fi

# Continuar con el comando especificado
exec "$@"
EOF
    fi

    # Construir imagen
    if $USE_GCR; then
        BACKEND_IMAGE="gcr.io/${PROJECT_ID}/coarlumini-backend:latest"
        docker build -t $BACKEND_IMAGE ..
        print_info "Subiendo imagen del backend a Google Container Registry..."
        docker push $BACKEND_IMAGE
    else
        docker build -t coarlumini-backend:latest ..
    fi

    print_success "Imagen del backend construida exitosamente."
}

# Construir imagen del frontend
build_frontend_image() {
    print_info "Construyendo imagen del frontend..."

    # Verificar si existe directorio frontend
    if [ ! -d "../frontend" ]; then
        print_error "No se encontró el directorio frontend. No se puede construir la imagen."
        return 1
    fi

    # Verificar si existe Dockerfile para el frontend
    if [ -f "../frontend/Dockerfile" ]; then
        # Construir imagen con Dockerfile existente
        if $USE_GCR; then
            FRONTEND_IMAGE="gcr.io/${PROJECT_ID}/coarlumini-frontend:latest"
            docker build -t $FRONTEND_IMAGE ../frontend/
            print_info "Subiendo imagen del frontend a Google Container Registry..."
            docker push $FRONTEND_IMAGE
        else
            docker build -t coarlumini-frontend:latest ../frontend/
        fi
    else
        print_warning "No se encontró Dockerfile para el frontend. Creando uno..."

        # Crear nginx.conf si no existe
        if [ ! -f "../frontend/nginx.conf" ]; then
            cat > ../frontend/nginx.conf << EOF
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /api {
        proxy_pass http://backend:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Cache control for static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }

    # Security headers
    add_header X-Content-Type-Options "nosniff";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Frame-Options "SAMEORIGIN";
}
EOF
        fi

        # Crear Dockerfile para frontend
        cat > ../frontend/Dockerfile << EOF
# Etapa de construcción
FROM node:20.19.0-alpine AS build

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

# Compilar aplicación
RUN npm run build

# Etapa de producción
FROM nginx:stable-alpine

# Copiar archivos compilados
COPY --from=build /app/dist /usr/share/nginx/html

# Copiar configuración de nginx
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
EOF

        # Construir imagen
        if $USE_GCR; then
            FRONTEND_IMAGE="gcr.io/${PROJECT_ID}/coarlumini-frontend:latest"
            docker build -t $FRONTEND_IMAGE ../frontend/
            print_info "Subiendo imagen del frontend a Google Container Registry..."
            docker push $FRONTEND_IMAGE
        else
            docker build -t coarlumini-frontend:latest ../frontend/
        fi
    fi

    print_success "Imagen del frontend construida exitosamente."
}

# Función principal
main() {
    # Mostrar banner
    echo "=================================================="
    echo "  Construcción de imágenes Docker para Coarlumini  "
    echo "=================================================="

    # Verificar dependencias
    verify_dependencies

    # Obtener información del proyecto si se usará GCR
    if $USE_GCR; then
        project_info
    fi

    # Construir imágenes
    build_database_image
    build_backend_image
    build_frontend_image

    # Resumen
    echo "=================================================="
    echo "  RESUMEN DE CONSTRUCCIÓN DE IMÁGENES  "
    echo "=================================================="

    if $USE_GCR; then
        echo "Imágenes construidas y subidas a Google Container Registry:"
        echo "- Base de datos: gcr.io/${PROJECT_ID}/coarlumini-database:latest"
        echo "- Backend: gcr.io/${PROJECT_ID}/coarlumini-backend:latest"
        echo "- Frontend: gcr.io/${PROJECT_ID}/coarlumini-frontend:latest"

        echo ""
        echo "Para usar estas imágenes en Kubernetes, actualiza los manifiestos de despliegue con las rutas correctas."
    else
        echo "Imágenes construidas localmente:"
        echo "- Base de datos: coarlumini-database:latest"
        echo "- Backend: coarlumini-backend:latest"
        echo "- Frontend: coarlumini-frontend:latest"
    fi

    print_success "Construcción de imágenes completada exitosamente."
}

# Ejecutar la función principal
main
