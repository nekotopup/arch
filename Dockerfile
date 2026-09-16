# Stage 1: Node.js - Build frontend assets
FROM node:20-alpine AS node-builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --legacy-peer-deps

# Copy source files for Vite build
COPY vite.config.js ./
COPY resources ./resources
COPY public ./public

# Build frontend (continue even if warnings)
RUN npm run build || true

# Stage 2: PHP - Application runtime
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

# Copy entire Laravel application
COPY --chown=www-data:www-data . .

# Create public/build directory
RUN mkdir -p public/build

# Copy built assets from node stage (if they exist)
COPY --from=node-builder /app/public/build/ ./public/build/ || true

# Install PHP dependencies
RUN composer install \
    --no-dev \
    --optimize-autoloader \
    --no-interaction \
    --no-progress

# Create required directories and set permissions
RUN mkdir -p \
    storage/logs \
    storage/app \
    storage/framework/views \
    storage/framework/cache \
    storage/framework/sessions \
    bootstrap/cache \
    database && \
    chown -R www-data:www-data /app && \
    chmod -R 755 storage bootstrap/cache && \
    chmod -R 775 storage/logs

# Copy nginx, PHP-FPM, and supervisor configs
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/php-fpm.conf /usr/local/etc/php-fpm.conf
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Generate app key (optional, will be overridden by env var)
RUN php artisan key:generate --force || true

# Cache config and routes for production
RUN php artisan config:cache || true && \
    php artisan route:cache || true && \
    php artisan view:cache || true && \
    php artisan storage:link || true

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# Start supervisor to manage nginx and php-fpm
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
