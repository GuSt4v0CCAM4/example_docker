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
