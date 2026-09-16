#!/bin/bash
set -e

echo "Installing PHP dependencies..."
composer install --optimize-autoloader --no-dev

echo "Installing Node dependencies..."
npm install

echo "Building frontend assets..."
npm run build

echo "Generating Laravel app key..."
php artisan key:generate --force || true

echo "Caching configuration..."
php artisan config:cache
php artisan route:cache
php artisan view:cache

echo "Creating storage symlink..."
php artisan storage:link || true

echo "✅ Build complete!"
