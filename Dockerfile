FROM php:8.2-apache

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
RUN sed -ri -e 's!/var/www/html!!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/!!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf
RUN a2enmod rewrite

# Directorio de trabajo
WORKDIR /var/www/html

# Configurar Git para que confíe en el directorio del proyecto
RUN git config --global --add safe.directory /var/www/html

# Copiar archivos de la aplicación
COPY . .

# Instalar dependencias
RUN composer install --no-dev --optimize-autoloader

# Permisos de directorios
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

# Exponer puerto
EXPOSE 80

# Comando para iniciar Apache
CMD ["apache2-foreground"]
