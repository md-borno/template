FROM php:8.2-fpm-alpine

# Install system dependencies
RUN apk add --no-cache \
    curl \
    libpng-dev \
    oniguruma-dev \
    libxml2-dev \
    zip \
    unzip \
    git \
    nodejs \
    npm \
    sqlite \
    supervisor \
    nginx

# Install PHP extensions
RUN docker-php-ext-install \
    pdo \
    pdo_sqlite \
    mbstring \
    exif \
    pcntl \
    bcmath \
    gd

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www

# Copy application files FIRST
COPY . /var/www

# Install PHP dependencies BEFORE npm build
RUN composer install --no-interaction --optimize-autoloader --no-dev

# NOW install Node dependencies and build assets (PHP is available)
RUN npm ci && npm run build

# Create storage directories and set permissions
RUN mkdir -p storage/logs database \
    && chmod -R 775 storage bootstrap/cache database \
    && chown -R www-data:www-data /var/www

# Generate APP_KEY
RUN php artisan key:generate --force

# Create SQLite database
RUN touch database/database.sqlite && chmod 775 database/database.sqlite

# Copy Nginx configuration
COPY docker/nginx.conf /etc/nginx/http.d/default.conf

# Copy Supervisor configuration
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Create necessary directories
RUN mkdir -p /var/log/supervisor /var/run/php-fpm

# Copy entrypoint script
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose port
EXPOSE 10000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:10000/health || exit 1

# Run entrypoint
ENTRYPOINT ["/entrypoint.sh"]
