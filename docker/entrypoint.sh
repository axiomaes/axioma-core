#!/bin/bash
set -e

echo "--> [Axioma Core] Container starting (EspoCRM 9.2.7)..."

# Global Variables
DB_HOST="$ESPOCRM_DATABASE_HOST"
DB_USER="$ESPOCRM_DATABASE_USER"
DB_PASS="$ESPOCRM_DATABASE_PASSWORD"
DB_NAME="$ESPOCRM_DATABASE_NAME"
DB_PORT="${ESPOCRM_DATABASE_PORT:-3306}"

CONFIG_INTERNAL="/var/www/html/data/config-internal.php"
CONFIG_FILE="/var/www/html/data/config.php"

# 1. Wait for Database
if [ -n "$DB_HOST" ]; then
    echo "--> Waiting for Database at $DB_HOST:$DB_PORT..."
    until mysqladmin ping -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" --password="$DB_PASS" --protocol=tcp --silent; do
        echo "    DB not ready, sleeping 2s..."
        sleep 2
    done
    echo "--> Database ready."
fi

# 2. Permissions Fix
echo "--> Fixing permissions for volumes..."
chown -R www-data:www-data /var/www/html/data /var/www/html/custom /var/www/html/client/custom

# 3. Config Initialization (Idempotent)

if [ -f "$CONFIG_INTERNAL" ]; then
    echo "--> [Check] $CONFIG_INTERNAL exists."
    echo "    Skipping generation to PRESERVE passwordSalt and cryptKey."
else
    echo "--> [First Run] Generating $CONFIG_INTERNAL..."
    
    # Key Generation Logic (PHP-based)
    # 1. Use ENV if provided
    # 2. Generate cryptographically secure hex string using PHP random_bytes
    
    SALT="${ESPOCRM_SALT}"
    CRYPT="${ESPOCRM_CRYPT_KEY}"
    
    if [ -z "$SALT" ]; then
        SALT=$(php -r 'echo bin2hex(random_bytes(16));')
        echo "    Generated new passwordSalt."
    fi
    
    if [ -z "$CRYPT" ]; then
        CRYPT=$(php -r 'echo bin2hex(random_bytes(16));')
        echo "    Generated new cryptKey."
    fi

    # Write config-internal.php safely
    cat > "$CONFIG_INTERNAL" <<EOF
<?php
return [
    'database' => [
        'driver' => 'pdo_mysql',
        'host' => '$DB_HOST',
        'port' => '$DB_PORT',
        'dbname' => '$DB_NAME',
        'user' => '$DB_USER',
        'password' => '$DB_PASS',
    ],
    'passwordSalt' => '$SALT',
    'cryptKey' => '$CRYPT',
];
EOF
    chown www-data:www-data "$CONFIG_INTERNAL"
fi

# 4. Safe Check for Main Config (Idempotent)
if [ ! -f "$CONFIG_FILE" ]; then
    echo "--> [Notice] config.php missing. Creating minimal default..."
    cat > "$CONFIG_FILE" <<EOF
<?php
return [
    'siteUrl' => '$ESPOCRM_SITE_URL',
    'useCache' => true,
];
EOF
    chown www-data:www-data "$CONFIG_FILE"
fi

# 5. Runtime Maintenance (Upgrade & Rebuild)
echo "--> Running Maintenance Sequence..."
su -s /bin/bash www-data -c "php command.php upgrade"
su -s /bin/bash www-data -c "php command.php rebuild"

echo "--> [Axioma Core] Ready. Starting Apache."
exec "$@"
