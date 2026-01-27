# ==========================================
# Stage 1: Builder (Downloads & Preparation)
# ==========================================
FROM php:8.3-apache AS builder

ARG ESPO_VERSION=9.2.7
ENV ESPO_ZIP=EspoCRM-${ESPO_VERSION}.zip
ENV ESPO_URL=https://www.espocrm.com/downloads/${ESPO_ZIP}

WORKDIR /stub

RUN apt-get update && apt-get install -y unzip wget && rm -rf /var/lib/apt/lists/*

# Download and unzip
# Logic: Unzip, find the specific extracted directory, and move it. 
# Fails explicitly if the expected folder pattern isn't found.
RUN wget -q ${ESPO_URL} && \
    unzip -q ${ESPO_ZIP} -d /stub && \
    DIR=$(find /stub -maxdepth 1 -type d -name "EspoCRM-*" | head -n 1) && \
    if [ -z "$DIR" ]; then echo "Error: EspoCRM source directory not found in zip"; exit 1; fi && \
    mv "$DIR" /stub/espocrm && \
    rm ${ESPO_ZIP}

# ==========================================
# Stage 2: Final Runtime Image
# ==========================================
FROM php:8.3-apache

# 1. Install System Dependencies & PHP Extensions
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libwebp-dev \
    libfreetype6-dev \
    libzip-dev \
    libicu-dev \
    libxml2-dev \
    libcurl4-openssl-dev \
    zip \
    unzip \
    git \
    mariadb-client \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        gd \
        zip \
        intl \
        exif \
        soap \
        bcmath \
    && rm -rf /var/lib/apt/lists/*

# 2. Apache Configuration
RUN a2enmod rewrite
# Fix .htaccess support globally (Critical)
RUN sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf

# 3. PHP Configuration
RUN echo "memory_limit = 512M" > /usr/local/etc/php/conf.d/espo-custom.ini \
    && echo "upload_max_filesize = 100M" >> /usr/local/etc/php/conf.d/espo-custom.ini \
    && echo "post_max_size = 100M" >> /usr/local/etc/php/conf.d/espo-custom.ini \
    && echo "max_execution_time = 180" >> /usr/local/etc/php/conf.d/espo-custom.ini \
    && echo "date.timezone = UTC" >> /usr/local/etc/php/conf.d/espo-custom.ini

# 4. Install EspoCRM (Copy from Builder)
WORKDIR /var/www/html
COPY --from=builder /stub/espocrm/ /var/www/html/

# 5. Inject Axioma Core (Branding Module)
# We COPY these *before* the first run so they are baked in.
# IMPORTANT: Directories must match EspoCRM module structure
COPY src/Backend /var/www/html/application/Espo/Modules/AxiomaCore
COPY src/Frontend /var/www/html/client/modules/axioma-core

# 6. Environment & Permissions
RUN mkdir -p /var/www/html/data /var/www/html/custom /var/www/html/client/custom \
    && chown -R www-data:www-data /var/www/html

# 7. Entrypoint
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["apache2-foreground"]
