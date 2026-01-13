#!/bin/bash
set -e

echo "🚀 Starting Laravel application initialization..."

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file from .env.example..."
    cp .env.example .env
fi

# Generate application key if not set
if ! grep -q "APP_KEY=base64:" .env; then
    echo "🔑 Generating Laravel application key..."
    php artisan key:generate --force
fi

# Set SQLite database for container
echo "🗄️ Configuring SQLite database..."
sed -i 's/DB_CONNECTION=mysql/DB_CONNECTION=sqlite/' .env
sed -i 's|DB_DATABASE=.*|DB_DATABASE=/tmp/database.sqlite|' .env

# Create SQLite database
echo "📊 Creating SQLite database..."
touch /tmp/database.sqlite
chmod 666 /tmp/database.sqlite

# Clear any existing cache
echo "🧹 Clearing Laravel cache..."
php artisan config:clear || true
php artisan route:clear || true
php artisan view:clear || true

# Run database migrations
echo "🔄 Running database migrations..."
php artisan migrate --force || true

# Cache configuration for better performance
echo "⚡ Caching configuration..."
php artisan config:cache

# Fix permissions
echo "🔐 Setting proper permissions..."
chown -R www-data:www-data /var/www/storage /var/www/bootstrap/cache
chmod -R 775 /var/www/storage /var/www/bootstrap/cache

echo "✅ Laravel initialization complete!"

# Start supervisord
echo "🔧 Starting services..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf