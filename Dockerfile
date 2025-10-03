FROM php:8.2-apache

# Instalar dependencias de Laravel
RUN apt-get update && apt-get install -y \
    libicu-dev libpq-dev libzip-dev zip unzip git curl \
    && docker-php-ext-install intl pdo pdo_mysql zip

# Habilitar mod_rewrite de Apache
RUN a2enmod rewrite

# Configurar Apache para Laravel
COPY ./docker/apache/laravel.conf /etc/apache2/sites-available/000-default.conf

# Copiar proyecto
WORKDIR /var/www/html
COPY . .

# Permisos para storage y cache
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

# Exponer el puerto
EXPOSE 80
