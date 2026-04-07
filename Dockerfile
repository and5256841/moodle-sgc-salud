FROM php:8.2-apache

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libicu-dev \
    libxml2-dev \
    libsodium-dev \
    libpq-dev \
    libonig-dev \
    unzip \
    cron \
    && rm -rf /var/lib/apt/lists/*

# Configure and install PHP extensions (dom first, then xmlreader which depends on it)
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    gd \
    intl \
    mysqli \
    pgsql \
    pdo_pgsql \
    zip \
    soap \
    sodium \
    exif \
    opcache \
    dom \
    xmlreader

# Enable Apache modules
RUN a2enmod rewrite headers

# PHP configuration
RUN echo "max_input_vars = 5000" > /usr/local/etc/php/conf.d/moodle.ini \
    && echo "upload_max_filesize = 50M" >> /usr/local/etc/php/conf.d/moodle.ini \
    && echo "post_max_size = 50M" >> /usr/local/etc/php/conf.d/moodle.ini \
    && echo "memory_limit = 256M" >> /usr/local/etc/php/conf.d/moodle.ini \
    && echo "max_execution_time = 300" >> /usr/local/etc/php/conf.d/moodle.ini

# OPcache configuration
RUN echo "opcache.enable=1" > /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.memory_consumption=128" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.max_accelerated_files=10000" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.revalidate_freq=60" >> /usr/local/etc/php/conf.d/opcache.ini

# Copy Moodle source
COPY moodle-src/ /var/www/html/

# Create moodledata directory
RUN mkdir -p /var/www/moodledata \
    && chown -R www-data:www-data /var/www/moodledata \
    && chmod -R 775 /var/www/moodledata \
    && chown -R www-data:www-data /var/www/html

# Copy startup script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Apache config - listen on PORT env variable
RUN sed -i 's/Listen 80/Listen ${PORT}/' /etc/apache2/ports.conf \
    && sed -i 's/:80/:${PORT}/' /etc/apache2/sites-available/000-default.conf

EXPOSE 10000

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
