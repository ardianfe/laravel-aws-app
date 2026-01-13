############################################
# Stage 1 — Build frontend assets
############################################
FROM node:18-alpine AS frontend-builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY resources ./resources
COPY vite.config.* ./
RUN npm run build


############################################
# Stage 2 — Install PHP dependencies
############################################
FROM composer:2 AS vendor-builder

WORKDIR /app

COPY composer.json composer.lock ./
RUN composer install \
    --no-dev \
    --no-interaction \
    --no-scripts \
    --prefer-dist \
    --optimize-autoloader

COPY . .
RUN composer dump-autoload --optimize


############################################
# Stage 3 — Production runtime
############################################
FROM php:8.3-fpm-alpine

# Install system dependencies (minimal)
RUN apk add --no-cache \
    nginx \
    supervisor \
    curl \
    icu-dev \
    oniguruma-dev \
    libxml2-dev \
    libpng-dev \
    zip \
    unzip

# Install PHP extensions
RUN docker-php-ext-install \
    pdo_mysql \
    mbstring \
    exif \
    bcmath \
    intl \
    gd

# Set working directory
WORKDIR /var/www

# Copy app source
COPY . .

# Copy vendor from builder
COPY --from=vendor-builder /app/vendor ./vendor

# Copy built assets
COPY --from=frontend-builder /app/public ./public

# Copy PHP config
COPY docker/php.ini /usr/local/etc/php/conf.d/app.ini

# Copy Nginx config
COPY docker/nginx.conf /etc/nginx/nginx.conf

# Copy Supervisor config
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Create basic .env file
RUN cp .env.example .env

# Set permissions
RUN chown -R www-data:www-data /var/www \
    && chmod -R 755 /var/www/storage /var/www/bootstrap/cache

# Create directories for logs
RUN mkdir -p /var/log/nginx /var/log/supervisor

# Expose HTTP
EXPOSE 80

# Healthcheck
HEALTHCHECK --interval=30s --timeout=5s \
  CMD curl -f http://localhost/ping || exit 1

# Runtime initialization and startup
CMD ["sh", "-c", "sed -i 's/DB_CONNECTION=mysql/DB_CONNECTION=sqlite/' .env && sed -i 's|DB_DATABASE=.*|DB_DATABASE=/tmp/database.sqlite|' .env && touch /tmp/database.sqlite && chmod 666 /tmp/database.sqlite && php artisan key:generate --force && php artisan migrate --force && exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf"]