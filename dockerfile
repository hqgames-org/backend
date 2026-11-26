# Utilizamos la última imagen de ubuntu como imagen base
FROM ubuntu:24.04

# Establecemos el timezone
ENV TZ=Europe/Madrid

# Instalamos software-properties-common para poder añadir repositorios externos
RUN apt-get update && apt-get install -y gnupg2 ca-certificates software-properties-common lsb-release

# Añadimos el repositorio oficial con las últimas versiones de PHP
RUN add-apt-repository ppa:ondrej/php -y

# Ahora instalamos especificando la rama 8.5 con sus extensiones. Además de apache
RUN apt-get update && apt-get install -y \
    apache2 \
    php8.5 \
    libapache2-mod-php8.5 \
    php8.5-cli \
    php8.5-common \
    php8.5-sqlite3 \
    php8.5-mysql \
    php8.5-pgsql \
    php8.5-gd \
    php8.5-zip \
    php8.5-bcmath \
    php8.5-mbstring \
    php8.5-xml \
    php8.5-curl \
    php8.5-intl \
    unzip \
    zip \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copiamos la configuración personalizada de Apache
COPY ./config/apache2.conf /etc/apache2/apache2.conf
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public

# Establecemos la raíz web de Apache en el directorio public del proyecto
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# Desactivamos el módulo autoindex y habilitamos rewrite
RUN a2dismod -f autoindex
RUN a2enmod rewrite
# Habilito ssl para usar https
RUN a2enmod ssl

# Creamos directorios de Apache
RUN mkdir -p /var/run/apache2 /var/lock/apache2 /var/log/apache2 && \
    chown -R www-data:www-data /var/run/apache2 /var/lock/apache2 /var/log/apache2

# Directorio de trabajo
WORKDIR /var/www/html/

# Copiamos código
COPY ./hqgames /var/www/html/
# Cambiamos permisos
RUN chmod 777 /tmp && \
    mkdir -p /var/www/html/storage/framework/views && \
    chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache && \
    chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Instalamos Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
RUN composer install --no-interaction --prefer-dist --optimize-autoloader

# Habilito el ssl y el sitio
RUN a2enmod ssl
COPY ./config/hqgames-ssl.conf /etc/apache2/sites-available/hqgames-ssl.conf
RUN a2dissite 000-default && a2ensite hqgames-ssl

EXPOSE 443

# Ejecutamos la preparación de carpetas, permisos y el arranque de Apache en el momento de levantar el contenedor
CMD bash -c "mkdir -p storage/framework/sessions storage/framework/views storage/framework/cache bootstrap/cache database \
    && chown -R www-data:www-data storage bootstrap/cache database \
    && chmod -R 777 storage bootstrap/cache database \
    && apachectl -D FOREGROUND"