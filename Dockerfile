# Simplified Dockerfile - PHP 8.2 with minimal extensions
FROM php:8.2-fpm-alpine

LABEL maintainer="Arch Topup"

# Install system dependencies and build tools
RUN apk add --no-cache \
    curl \
    git \
    supervisor \
    sqlite \
    sqlite-libs \
    postgresql-dev \
    mysql-client \
    nginx \
    bash \
    oniguruma-dev \
    libzip-dev

# Install PHP extensions one by one with error handling
RUN docker-php-ext-install -j$(nproc) pdo || true
RUN docker-php-ext-install -j$(nproc) pdo_sqlite || true
RUN docker-php-ext-install -j$(nproc) pdo_pgsql || true
RUN docker-php-ext-install -j$(nproc) pdo_mysql || true
RUN docker-php-ext-install -j$(nproc) bcmath || true
RUN docker-php-ext-install -j$(nproc) ctype || true
RUN docker-php-ext-install -j$(nproc) fileinfo || true
RUN docker-php-ext-install -j$(nproc) json || true
RUN docker-php-ext-install -j$(nproc) mbstring || true
RUN docker-php-ext-install -j$(nproc) tokenizer || true
RUN docker-php-ext-install -j$(nproc) xml || true

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /app

# Copy entire application
COPY . .

# Fix permissions before composer install
RUN chown -R nobody:nobody /app

# Install PHP dependencies as unprivileged user
RUN composer install \
    --no-dev \
    --optimize-autoloader \
    --no-interaction \
    --no-progress \
    --no-suggest

# Create required directories
RUN mkdir -p \
    storage/logs \
    storage/app \
    storage/framework/views \
    storage/framework/cache \
    storage/framework/sessions \
    bootstrap/cache \
    database \
    public/build

# Set proper permissions for www-data
RUN chown -R www-data:www-data /app && \
    chmod -R 755 storage bootstrap/cache && \
    chmod -R 775 storage/logs

# Copy config files
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/php-fpm.conf /usr/local/etc/php-fpm.conf
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Generate app key
RUN php artisan key:generate --force || echo "Key generation skipped"

# Cache Laravel configuration
RUN php artisan config:cache || echo "Config cache skipped" && \
    php artisan route:cache || echo "Route cache skipped" && \
    php artisan view:cache || echo "View cache skipped" && \
    php artisan storage:link || echo "Storage link skipped"

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
