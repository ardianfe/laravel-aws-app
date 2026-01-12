FROM php:8.3-fpm

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libsqlite3-dev \
    sqlite3 \
    zip \
    unzip \
    default-mysql-client \
    nginx \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-install pdo_mysql pdo_sqlite mbstring exif pcntl bcmath gd sockets

# Get latest Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Create system user to run Composer and Artisan Commands
RUN useradd -G www-data,root -u 1000 -d /home/laravel laravel
RUN mkdir -p /home/laravel/.composer && \
    chown -R laravel:laravel /home/laravel

# Set working directory
WORKDIR /var/www

# Copy existing application directory contents
COPY . /var/www

# Copy existing application directory permissions
COPY --chown=laravel:laravel . /var/www

# Install dependencies
RUN composer install --optimize-autoloader --no-dev

# Set proper permissions
RUN chown -R laravel:www-data /var/www
RUN chmod -R 775 /var/www/storage /var/www/bootstrap/cache

# Configure Nginx
COPY <<EOF /etc/nginx/sites-available/default
server {
    listen 80;
    server_name localhost;
    root /var/www/public;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# Configure Supervisor
COPY <<EOF /etc/supervisor/conf.d/supervisord.conf
[supervisord]
nodaemon=true

[program:nginx]
command=nginx -g "daemon off;"
autostart=true
autorestart=true
stderr_logfile=/var/log/nginx/error.log
stdout_logfile=/var/log/nginx/access.log

[program:php-fpm]
command=php-fpm
autostart=true
autorestart=true
stderr_logfile=/var/log/php-fpm.log
stdout_logfile=/var/log/php-fpm.log
EOF

# Create log directories
RUN mkdir -p /var/log/nginx && \
    touch /var/log/php-fpm.log && \
    chown laravel:laravel /var/log/php-fpm.log

# Expose port 80
EXPOSE 80

# Create startup script
COPY <<EOF /usr/local/bin/start.sh
#!/bin/bash
# Create SQLite database if it doesn't exist
touch /tmp/database.sqlite
chmod 664 /tmp/database.sqlite

# Start supervisor
exec /usr/bin/supervisord
EOF

RUN chmod +x /usr/local/bin/start.sh

# Start with custom script
CMD ["/usr/local/bin/start.sh"]