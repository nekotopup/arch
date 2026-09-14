# Build stage
FROM composer:2 as builder
WORKDIR /app
COPY composer.* ./
RUN composer install --no-dev --optimize-autoloader

# Runtime stage
FROM php:8.2-cli
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libpq-dev \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-install pdo pdo_sqlite pdo_pgsql

# Copy from builder
COPY --from=builder /app/vendor ./vendor
COPY . .

# Install Node dependencies and build assets
RUN apt-get update && apt-get install -y nodejs npm && rm -rf /var/lib/apt/lists/*
RUN npm install && npm run build

# Generate app key
RUN php artisan key:generate --force || true

# Expose port
EXPOSE 10000

# Run migrations and start server
CMD php artisan migrate --force && php artisan serve --host=0.0.0.0 --port=10000
