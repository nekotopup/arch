# Simplified Dockerfile - PHP only, assets pre-built locally
FROM php:8.2-fpm-alpine

LABEL maintainer="Arch Topup"

# Install system dependencies
RUN apk add --no-cache \
    curl \
    git \
    supervisor \
    sqlite \
    sqlite-libs \
    postgresql-client \
    mysql-client \
    nginx \
    bash

# Install PHP extensions
RUN docker-php-ext-install \
    pdo \
    pdo_sqlite \
    pdo_pgsql \
    pdo_mysql \
    bcmath \
    ctype \
    fileinfo \
    json \
    mbstring \
    tokenizer \
    xml

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /app

# Copy entire application (public/build should already exist locally)
COPY --chown=www-data:www-data . .

# Install PHP dependencies
RUN composer install \
    --no-dev \
    --optimize-autoloader \
    --no-interaction \
    --no-progress

# Create required directories
RUN mkdir -p \
    storage/logs \
    storage/app \
    storage/framework/views \
    storage/framework/cache \
    storage/framework/sessions \
    bootstrap/cache \
    database

# Set permissions
RUN chown -R www-data:www-data /app && \
    chmod -R 755 storage bootstrap/cache && \
    chmod -R 775 storage/logs

# Copy config files
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/php-fpm.conf /usr/local/etc/php-fpm.conf
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Cache Laravel config/routes/views
RUN php artisan key:generate --force || true && \
    php artisan config:cache || true && \
    php artisan route:cache || true && \
    php artisan view:cache || true && \
    php artisan storage:link || true

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
