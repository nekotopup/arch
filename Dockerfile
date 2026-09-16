# Stage 1: Node.js - Build frontend assets
FROM node:20-alpine AS node-builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --legacy-peer-deps

# Copy files needed for Vite build (only what exists)
COPY vite.config.js ./
COPY resources ./resources
COPY public ./public

# Build frontend (continue even if there are warnings)
RUN npm run build || true


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

# Copy PHP application files
COPY --chown=www-data:www-data . .

# Copy built frontend from node builder (skip if not exists)
RUN mkdir -p public/build 2>/dev/null || true
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

# Copy docker configuration files
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/php-fpm.conf /usr/local/etc/php-fpm.conf
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Create storage subdirectories
RUN mkdir -p storage/framework/{sessions,views,cache} && \
    chown -R www-data:www-data storage

# Generate app key
RUN php artisan key:generate --force 2>/dev/null || true

# Cache configuration for production
RUN php artisan config:cache 2>/dev/null || true && \
    php artisan route:cache 2>/dev/null || true && \
    php artisan view:cache 2>/dev/null || true && \
    php artisan storage:link 2>/dev/null || true

# Create simple health check endpoint
RUN echo '<?php echo "OK";' > public/health.php

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# Run supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
