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
    icu-dev \
    libxml2-dev \
    freetype-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    $PHPIZE_DEPS

# =========================================================
# PHP extensions
# =========================================================
RUN docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        bcmath \
        exif \
        gd \
        intl \
        mbstring \
        pdo \
        pdo_mysql \
        pdo_pgsql \
        pdo_sqlite \
        xml \
        zip

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
    && chmod -R 755 storage bootstrap/cache \
    && chmod -R 775 storage/logs

# =========================================================
# Docker configuration
# =========================================================
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/php-fpm.conf /usr/local/etc/php-fpm.conf
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# =========================================================
# Laravel cache
# =========================================================
RUN php artisan config:cache || echo "Config cache skipped" \
    && php artisan route:cache || echo "Route cache skipped" \
    && php artisan view:cache || echo "View cache skipped" \
    && php artisan storage:link || echo "Storage link skipped"

EXPOSE 80

# =========================================================
# Health check
# =========================================================
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# =========================================================
# Start
# =========================================================
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
