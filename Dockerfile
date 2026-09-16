# Stage 1: Node.js - Build frontend assets
FROM node:20-alpine AS node-builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --legacy-peer-deps

# Copy only the files needed for Vite build
COPY vite.config.js ./
COPY tsconfig.json ./ 2>/dev/null || true
COPY resources ./resources
COPY public ./public

# Build frontend
RUN npm run build 2>&1 || exit 0

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

# Copy PHP application files (excluding public/build which will come from node-builder)
COPY --chown=www-data:www-data . .

# Copy built frontend from node builder (if it exists)
COPY --from=node-builder --chown=www-data:www-data /app/public/build ./public/build 2>/dev/null || true

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

# Copy docker configuration files
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/php-fpm.conf /usr/local/etc/php-fpm.conf
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Create storage subdirectories
RUN mkdir -p storage/framework/{sessions,views,cache} && \
    chown -R www-data:www-data storage

# Generate app key if not exists
RUN php artisan key:generate --force 2>/dev/null || true

# Cache config, routes and views for production
RUN php artisan config:cache && \
    php artisan route:cache && \
    php artisan view:cache && \
    php artisan storage:link 2>/dev/null || true

# Create health check endpoint
RUN echo '<?php echo "OK";' > public/health.php

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# Run supervisor to manage PHP-FPM and Nginx
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
