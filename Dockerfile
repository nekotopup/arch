
FROM php:8.2-fpm-alpine

LABEL maintainer="Arch Topup"

# =========================================================
# System dependencies
# =========================================================
RUN apk add --no-cache \
    bash \
    curl \
    git \
    nginx \
    supervisor \
    sqlite \
    sqlite-libs \
    postgresql-dev \
    mysql-client \
    oniguruma-dev \
    libzip-dev \
    libxml2-dev

# =========================================================
# PHP Extensions
# =========================================================

RUN docker-php-ext-install bcmath

RUN docker-php-ext-install mbstring

RUN docker-php-ext-install pdo_mysql

RUN docker-php-ext-install pdo_pgsql

RUN docker-php-ext-install pdo_sqlite

RUN docker-php-ext-install xml

RUN docker-php-ext-install zip

# =========================================================
# Check PHP
# =========================================================
RUN php -v && php -m

# =========================================================
# Composer
# =========================================================
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# =========================================================
# Application
# =========================================================
WORKDIR /app

COPY . .

# =========================================================
# Composer dependencies
# =========================================================
RUN composer install \
    --no-dev \
    --optimize-autoloader \
    --no-interaction \
    --no-progress

# =========================================================
# Laravel directories
# =========================================================
RUN mkdir -p \
    storage/logs \
    storage/app \
    storage/framework/views \
    storage/framework/cache \
    storage/framework/sessions \
    bootstrap/cache \
    database \
    public/build

# =========================================================
# Permissions
# =========================================================
RUN chown -R www-data:www-data /app \
    && chmod -R 755 storage \
    && chmod -R 755 bootstrap/cache \
    && chmod -R 775 storage/logs

# =========================================================
# Docker configuration
# =========================================================
COPY docker/nginx.conf /etc/nginx/nginx.conf

COPY docker/php-fpm.conf /usr/local/etc/php-fpm.conf

COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# =========================================================
# Laravel setup
# =========================================================

RUN php artisan key:generate --force \
    || echo "Key generation skipped"

RUN php artisan config:cache \
    || echo "Config cache skipped"

RUN php artisan route:cache \
    || echo "Route cache skipped"

RUN php artisan view:cache \
    || echo "View cache skipped"

RUN php artisan storage:link \
    || echo "Storage link skipped"

# =========================================================
# Port
# =========================================================
EXPOSE 80

# =========================================================
# Health check
# =========================================================
HEALTHCHECK \
    --interval=30s \
    --timeout=10s \
    --start-period=40s \
    --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# =========================================================
# Start Supervisor
# =========================================================
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
