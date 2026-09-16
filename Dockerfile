
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
    libzip-dev

# =========================================================
# PHP Extensions
# =========================================================
RUN docker-php-ext-install -j$(nproc) \
    bcmath \
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
# Application directory
# =========================================================
WORKDIR /app

# =========================================================
# Copy application
# =========================================================
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
# Nginx configuration
# =========================================================
COPY docker/nginx.conf /etc/nginx/nginx.conf

# =========================================================
# PHP-FPM configuration
# =========================================================
COPY docker/php-fpm.conf /usr/local/etc/php-fpm.conf

# =========================================================
# Supervisor configuration
# =========================================================
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# =========================================================
# Laravel configuration
# =========================================================

# Generate APP_KEY only if possible.
# In production, preferably provide APP_KEY through environment variables.
RUN php artisan key:generate --force || echo "Key generation skipped"

# Cache Laravel configuration
RUN php artisan config:cache || echo "Config cache skipped"

RUN php artisan route:cache || echo "Route cache skipped"

RUN php artisan view:cache || echo "View cache skipped"

# Create storage symlink
RUN php artisan storage:link || echo "Storage link skipped"

# =========================================================
# Expose HTTP port
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
```
