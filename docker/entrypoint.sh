#!/bin/bash
set -e

log() {
    echo "--> [Axioma Core] $*"
}

log "Container starting (EspoCRM 9.2.7)..."

# =========================================================
# Global Variables
# =========================================================
DB_HOST="$ESPOCRM_DATABASE_HOST"
DB_USER="$ESPOCRM_DATABASE_USER"
DB_PASS="$ESPOCRM_DATABASE_PASSWORD"
DB_NAME="$ESPOCRM_DATABASE_NAME"
DB_PORT="${ESPOCRM_DATABASE_PORT:-3306}"

AXIOMA_PROFILE="${AXIOMA_PROFILE:-default}"

CONFIG_INTERNAL="/var/www/html/data/config-internal.php"
CONFIG_FILE="/var/www/html/data/config.php"
CONFIG_OVERRIDE="/var/www/html/data/config-override.php"

# =========================================================
# 1. Wait for Database
# =========================================================
if [ -n "$DB_HOST" ]; then
    log "Waiting for Database at $DB_HOST:$DB_PORT..."
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
    log "Database ready."
fi

# =========================================================
# 2. Apply Overrides (Base + Profile) — SAFE MERGE
# =========================================================
apply_override() {
    local src="$1"
    local dest="/var/www/html"

    if [ -d "$src" ]; then
        log "Merging overrides: $src -> $dest"
        # Check if rsync is available (preferred)
        if command -v rsync >/dev/null 2>&1; then
            # -a: archive mode, --no-o --no-g: don't preserve owner/group (we fix later)
            # --omit-dir-times: prevent timestamp issues on dirs
            rsync -a --no-o --no-g --omit-dir-times "$src/" "$dest/"
        else
            # Fallback to cp (recursive, no clobber check, simple overwrite)
            cp -R "$src/." "$dest/"
        fi
    fi
}

log "Applying overrides (Profile: $AXIOMA_PROFILE)"

# Base (Axioma Core defaults)
apply_override "/stub/overrides/base"

# Profile (client-specific)
PROFILE_PATH="/stub/overrides/profiles/$AXIOMA_PROFILE"
if [ -d "$PROFILE_PATH" ]; then
    apply_override "$PROFILE_PATH"
else
    log "Warning: profile '$AXIOMA_PROFILE' not found. Using base only."
fi

# =========================================================
# 3. Fix Permissions
# =========================================================
log "Fixing permissions..."
chown -R www-data:www-data \
    /var/www/html/data \
    /var/www/html/custom \
    /var/www/html/client/custom || true

# =========================================================
# 4. Config Initialization (Idempotent, SAFE)
# =========================================================
if [ -f "$CONFIG_INTERNAL" ]; then
    log "config-internal.php exists. Preserving cryptKey and passwordSalt."
else
    log "First run: generating config-internal.php"

    SALT="$ESPOCRM_SALT"
    CRYPT="$ESPOCRM_CRYPT_KEY"

    if [ -z "$SALT" ]; then
        SALT=$(php -r 'echo bin2hex(random_bytes(16));')
        log "Generated new passwordSalt."
    fi

    if [ -z "$CRYPT" ]; then
        CRYPT=$(php -r 'echo bin2hex(random_bytes(16));')
        log "Generated new cryptKey."
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
# 5. Ensure config.php Exists (Base Runtime Config)
# =========================================================
if [ ! -f "$CONFIG_FILE" ]; then
    log "config.php missing. Creating minimal default."
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
# 6. Merge config-override.php (Profile Branding / Flags)
# =========================================================
if [ -f "$CONFIG_OVERRIDE" ]; then
    log "Merging config-override.php into config.php"
    php -r '
        $baseFile = "/var/www/html/data/config.php";
        $ovrFile  = "/var/www/html/data/config-override.php";

        $base = file_exists($baseFile) ? include $baseFile : [];
        $ovr  = include $ovrFile;

        if (!is_array($base)) $base = [];
        if (!is_array($ovr))  $ovr = [];

        $merged = array_replace_recursive($base, $ovr);
        $out = "<?php\nreturn " . var_export($merged, true) . ";\n";
        file_put_contents($baseFile, $out);
    '
    chown www-data:www-data "$CONFIG_FILE"
fi

# =========================================================
# 7. Maintenance Sequence (CRITICAL ORDER)
# =========================================================
log "Running maintenance sequence..."
su -s /bin/bash www-data -c "php command.php clear-cache"

# Check if Schema exists (look for 'user' table)
# Check if Schema exists (look for 'user' table)
# We add "|| echo '0'" to handle cases where php exits non-zero (e.g. connection error) so the script doesn't crash under set -e
TABLE_EXISTS=$(php -r "
    try {
        \$pdo = new PDO('mysql:host=$DB_HOST;port=$DB_PORT;dbname=$DB_NAME', '$DB_USER', '$DB_PASS');
        \$stmt = \$pdo->query(\"SHOW TABLES LIKE 'user'\");
        echo \$stmt->rowCount() > 0 ? '1' : '0';
    } catch (PDOException \$e) {
        echo '0';
    }
" || echo '0')

if [ "$TABLE_EXISTS" == "1" ]; then
    log "Existing schema detected. Running upgrade..."
    su -s /bin/bash www-data -c "php command.php upgrade"
else
    log "Fresh database detected (no 'user' table). Skipping upgrade."
fi

su -s /bin/bash www-data -c "php command.php rebuild"

# =========================================================
# 8. Start Apache
# =========================================================
log "Axioma Core ready. Starting Apache."
exec "$@"
