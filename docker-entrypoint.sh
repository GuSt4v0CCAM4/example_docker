#!/bin/sh
set -e

# Esperar a la base de datos
if [ -n "${DB_HOST}" ]; then
    echo "Esperando conexión a la base de datos..."
    TIMEOUT=30
    COUNT=0
    until nc -z "${DB_HOST}" "${DB_PORT:-3306}" || [ $COUNT -eq $TIMEOUT ]; do
        COUNT=$((COUNT+1))
        sleep 1
        echo "Esperando base de datos... $COUNT/$TIMEOUT"
    done
    if [ $COUNT -eq $TIMEOUT ]; then
        echo "Tiempo de espera agotado, continuando de todos modos"
    else
        echo "Conexión a base de datos establecida"
    fi
fi

# Generar clave de aplicación si no existe
if [ -z "${APP_KEY}" ] || [ "${APP_KEY}" = "base64:base64:" ]; then
    echo "Generando clave de aplicación..."
    php artisan key:generate --force
fi

# Ejecutar migraciones
echo "Ejecutando migraciones..."
php artisan migrate --force

# Optimizaciones
if [ "${APP_ENV}" = "production" ]; then
    echo "Entorno de producción detectado, aplicando optimizaciones..."
    php artisan config:cache
    php artisan route:cache
    php artisan view:cache
else
    echo "Limpiando caché para entorno de desarrollo..."
    php artisan config:clear
    php artisan cache:clear
    php artisan view:clear
    php artisan route:clear
fi

echo "Iniciando servidor PHP en el puerto 8000..."
exec "$@"
