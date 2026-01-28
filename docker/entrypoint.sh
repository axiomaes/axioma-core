#!/bin/bash
set -e

echo "--> [Axioma Core] Container starting (EspoCRM 9.2.7)..."

# =========================================================
# Global Variables
# =========================================================
DB_HOST="$ESPOCRM_DATABASE_HOST"
DB_USER="$ESPOCRM_DATABASE_USER"
DB_PASS="$ESPOCRM_DATABASE_PASSWORD"
DB_NAME="$ESPOCRM_DATABASE_NAME"
DB_PORT="${ESPOCRM_DATABASE_PORT:-3306}"

CONFIG_INTERNAL="/var/www/html/data/config-internal.php"
CONFIG_FILE="/var/www/html/data/config.php"

# =========================================================
# 1. Wait for Database
# =========================================================
if [ -n "$DB_HOST" ]; then
    echo "--> Waiting for Database at $DB_HOST:$DB_PORT..."
    until mysqladmin ping \
        -h "$DB_HOST" \
        -P "$DB_PORT" \
        -u "$DB_USER" \
        --password="$DB_PASS" \
        --protocol=tcp \
        --skip-ssl \
        --silent; do
        echo "    DB not ready, sleeping 2s..."
        sleep 2
    done
    echo "--> Database ready."
fi

# =========================================================
# 2. Apply Branding Overrides (Runtime Persist)
# =========================================================
echo "--> Applying Axioma Core branding overrides..."
if [ -d "/stub/overrides" ]; then
    cp -R /stub/overrides/* /var/www/html/
fi

# =========================================================
# 3. Fix Permissions (Volumes + Custom)
# =========================================================
echo "--> Fixing permissions for volumes..."
chown -R www-data:www-data \
    /var/www/html/data \
    /var/www/html/custom \
    /var/www/html/client/custom

# =========================================================
# 4. Config Initialization (Idempotent)
# =========================================================
if [ -f "$CONFIG_INTERNAL" ]; then
    echo "--> [Check] config-internal.php exists."
    echo "    Skipping generation to PRESERVE passwordSalt and cryptKey."
else
    echo "--> [First Run] Generating config-internal.php..."

    SALT="$ESPOCRM_SALT"
    CRYPT="$ESPOCRM_CRYPT_KEY"

    if [ -z "$SALT" ]; then
        SALT=$(php -r 'echo bin2hex(random_bytes(16));')
        echo "    Generated new passwordSalt."
    fi

    if [ -z "$CRYPT" ]; then
        CRYPT=$(php -r 'echo bin2hex(random_bytes(16));')
        echo "    Generated new cryptKey."
    fi

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

# =========================================================
# 5. Ensure config.php Exists (Safe Default)
# =========================================================
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

# =========================================================
# 6. Maintenance Sequence (CRITICAL ORDER)
# =========================================================
echo "--> Running Maintenance Sequence..."
su -s /bin/bash www-data -c "php command.php clear-cache"
su -s /bin/bash www-data -c "php command.php upgrade"
su -s /bin/bash www-data -c "php command.php rebuild"

# =========================================================
# 7. Start Apache
# =========================================================
echo "--> [Axioma Core] Ready. Starting Apache."
exec "$@"
