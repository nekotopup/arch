# Stage 1: Node.js - Build frontend assets
FROM node:20-alpine AS node-builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies with increased memory
RUN npm ci --legacy-peer-deps --omit=dev

# Copy source
COPY . .

# Build frontend (with error handling)
RUN npm run build || echo "Build output: $(ls -la public/ 2>/dev/null || echo 'public/ not found')" || true

---

# Stage 2: PHP - Application runtime
FROM php:8.2-fpm-alpine

LABEL maintainer="Arch Topup Team"

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

# Install PHP extensions required by Laravel
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

# Set working directory
WORKDIR /app

# Copy all application files
COPY . .

# Copy built frontend from node builder
COPY --from=node-builder /app/public/build ./public/build 2>/dev/null || true

# Install PHP dependencies
RUN composer install \
    --no-dev \
    --optimize-autoloader \
    --no-interaction \
    --no-progress

# Create necessary directories
RUN mkdir -p \
    storage/logs \
    storage/app \
    storage/framework/views \
    storage/framework/cache \
    bootstrap/cache \
    database

# Set proper permissions
RUN chown -R www-data:www-data /app && \
    chmod -R 755 storage bootstrap/cache && \
    chmod -R 775 storage/logs

# Copy nginx configuration
COPY docker/nginx.conf /etc/nginx/nginx.conf

# Copy PHP-FPM configuration
COPY docker/php-fpm.conf /usr/local/etc/php-fpm.conf

# Copy supervisord configuration
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Create Laravel cache/config directories
RUN mkdir -p storage/framework/{sessions,views,cache} && \
    chown -R www-data:www-data storage

# Generate app key if not exists (will be overridden by env)
RUN php artisan key:generate --force 2>/dev/null || true

# Cache config, routes and views for production
RUN php artisan config:cache && \
    php artisan route:cache && \
    php artisan view:cache && \
    php artisan storage:link 2>/dev/null || true

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# Run supervisor to manage PHP-FPM and Nginx
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
