# Utilizamos la última imagen de ubuntu como imagen base
FROM ubuntu:latest

# Establecemos el timezone no interactivo para evitar pausas en la construcción
ENV TZ=Europe/Madrid
ENV DEBIAN_FRONTEND=noninteractive

# Definimos el directorio público de Laravel como raíz de Apache
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public

# Instalamos Apache y PHP (incluyendo php-sqlite3)
RUN apt-get update && \
    apt-get install -y \
        apache2 \
        php \
        libapache2-mod-php \
        php-cli \
        php-common \
        php-mysql \
        php-pgsql \
        php-sqlite3 \
        php-gd \
        php-zip \
        php-bcmath \
        php-mbstring \
        php-xml \
        php-curl \
        php-intl \
        unzip \
        zip \
        git \
        curl \
        && rm -rf /var/lib/apt/lists/*

# Habilitamos mod_rewrite de Apache para las rutas de Laravel
RUN a2enmod rewrite

# Copiamos la configuración personalizada de Apache
COPY ./config/apache2.conf /etc/apache2/apache2.conf

# Establecemos la raíz web de Apache en el directorio public del proyecto
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf && \
    sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# Desactivamos el módulo autoindex
RUN a2dismod -f autoindex

# Creamos directorios necesarios con permisos para el usuario de apache
RUN mkdir -p /var/run/apache2 /var/lock/apache2 /var/log/apache2 && \
    chown -R www-data:www-data /var/run/apache2 /var/lock/apache2 /var/log/apache2

# Establecemos el directorio de trabajo
WORKDIR /var/www/html/

# Instalamos Composer desde la imagen oficial
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Copiamos el código asignando usuario root y grupo www-data (solo lectura para el grupo)
COPY --chown=root:www-data ./hqgames /var/www/html/

# Asignamos propiedad y permisos de escritura ÚNICAMENTE a storage y bootstrap/cache
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache && \
    chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Asegurar permisos correctos en /tmp y en el almacenamiento de cache de Blade
RUN chmod 1777 /tmp && \
    mkdir -p /var/www/html/storage/framework/views && \
    chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache && \
    chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Cambiamos temporalmente a www-data para ejecutar composer sin permisos de root
USER www-data

# Instalamos las dependencias de Composer
RUN composer install \
    --no-interaction \
    --no-dev \
    --prefer-dist \
    --optimize-autoloader

# Volvemos a ROOT para exponer puerto e iniciar Apache
USER root

EXPOSE 80

CMD ["apachectl", "-D", "FOREGROUND"]
