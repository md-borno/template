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
    sqlite

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

# Copy application files
COPY . /var/www

# Install PHP dependencies
RUN composer install --no-interaction --optimize-autoloader --no-dev

# Install Node dependencies and build assets
RUN npm ci && npm run build

# Create storage directories and set permissions
RUN mkdir -p storage/logs \
    && chmod -R 775 storage bootstrap/cache \
    && chown -R www-data:www-data /var/www

# Generate APP_KEY if not present
RUN php artisan key:generate --force

# Create SQLite database directory
RUN mkdir -p database && touch database/database.sqlite && chmod 775 database

# Create cache and session tables
RUN php artisan migrate --force

# Create supervisor config directory
RUN mkdir -p /etc/supervisor/conf.d

# Copy Nginx configuration
COPY docker/nginx.conf /etc/nginx/nginx.conf

# Copy Supervisor configuration
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Install supervisord for process management
RUN apk add --no-cache supervisor

# Expose port (Render uses PORT env variable)
EXPOSE 10000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:10000/health || exit 1

# Start application
CMD php artisan serve --host=0.0.0.0 --port=10000
