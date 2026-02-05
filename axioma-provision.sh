#!/bin/bash
set -euo pipefail

# ==============================================================================
# Axioma Core - Client Provisioning Script for CapRover (HARDENED)
# ==============================================================================
# Usage: ./axioma-provision.sh <client_id> <domain> <profiles>
# Example: ./axioma-provision.sh viajes-lopez crm.viajeslopez.com core-business,pack-travel-agency
# ==============================================================================
# NON-GOALS / CONSTRAINTS:
# 1. This script does NOT create the SQL database. It must exist beforehand.
# 2. This script is NOT for updating existing clients. It fails if App exists.
# 3. Requires CapRover CLI authenticated (`caprover login`).
# ==============================================================================

# --------------------------------------------------
# 0. Secrets & Configuration
# --------------------------------------------------
# Load from .env if present
if [ -f .env ]; then
    # shellcheck disable=SC1091
    source .env
fi

# Validation: Check required secrets are present in environment
# Use shell parameter expansion to fail with error if unset
: "${AXIOMA_DB_HOST:?Error: AXIOMA_DB_HOST env var is missing.}"
: "${AXIOMA_DB_USER:?Error: AXIOMA_DB_USER env var is missing.}"
: "${AXIOMA_DB_PASS:?Error: AXIOMA_DB_PASS env var is missing.}"
: "${AXIOMA_DB_PORT:=3306}" # Default to 3306 if unset

DB_PREFIX="axioma_"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[AXIOMA] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; exit 1; }

# --------------------------------------------------
# 1. Input Validation
# --------------------------------------------------
if [ "$#" -ne 3 ]; then
    error "Usage: $0 <client_id> <domain> <profiles>"
fi

CLIENT_ID=$1
DOMAIN=$2
PROFILES=$3

APP_NAME="axioma-${CLIENT_ID}"
DB_NAME="${DB_PREFIX}${CLIENT_ID//-/_}" # Convert hyphens to underscores

log "Starting provisioning for Client: $CLIENT_ID"
log "  App Name:   $APP_NAME"
log "  Domain:     $DOMAIN"
log "  Profiles:   $PROFILES"
log "  DB Target:  $DB_NAME (Must exist!)"

# Check Prerequisites
if ! command -v caprover &> /dev/null; then
    error "CapRover CLI not found. Please install: npm install -g caprover"
fi

# --------------------------------------------------
# 2. CapRover API Helper
# --------------------------------------------------
cap_api() {
    local path="$1"
    local method="${2:-GET}"
    local data="${3:-{}}"
    
    # Execute API call using CLI
    caprover api --path "$path" --method "$method" --data "$data" --json
}

# --------------------------------------------------
# 3. Safety Check: App Existence
# --------------------------------------------------
log "Step 0: Verifying App uniqueness..."

# Fetch list of app definitions and check if our app name is present.
# We explicitly avoid 'jq' to stick to standard tools (grep).
# 'caprover api' outputs JSON. 
EXISTING_APPS=$(cap_api "/user/apps/appDefinitions" "GET" "{}")

if echo "$EXISTING_APPS" | grep -q "\"appName\":\"$APP_NAME\""; then
    error "App '$APP_NAME' ALREADY EXISTS in CapRover. \n       This script creates NEW clients only. Aborting for safety."
fi

# --------------------------------------------------
# 4. Create App
# --------------------------------------------------
log "Step 1: Creating App '$APP_NAME'..."

# Create the app
cap_api "/user/apps/appDefinitions/register" "POST" \
    "{\"appName\":\"$APP_NAME\",\"hasPersistentData\":true}" > /dev/null

# --------------------------------------------------
# 5. Configure Persistent Volumes
# --------------------------------------------------
log "Step 2: Configuring Volumes..."

VOLUMES_JSON='[
    {"pathInContainer":"/var/www/html/data","label":"data"},
    {"pathInContainer":"/var/www/html/custom","label":"custom"},
    {"pathInContainer":"/var/www/html/client/custom","label":"client-custom"}
]'

cap_api "/user/apps/appDefinitions/update" "POST" \
    "{\"appName\":\"$APP_NAME\",\"persistentDirectories\":$VOLUMES_JSON}" > /dev/null

# --------------------------------------------------
# 6. Environment Variables
# --------------------------------------------------
log "Step 3: Setting Environment Variables..."

# Construct JSON manually to avoid dependencies, ensuring secrets are inserted
# Note: In production bash, proceed with caution on escaping. 
# Here simple variables are safe-ish, but DB_PASS needs care if it has quotes.

ENV_VARS_JSON="[
    {\"key\":\"ESPOCRM_DATABASE_HOST\",\"value\":\"$AXIOMA_DB_HOST\"},
    {\"key\":\"ESPOCRM_DATABASE_PORT\",\"value\":\"$AXIOMA_DB_PORT\"},
    {\"key\":\"ESPOCRM_DATABASE_USER\",\"value\":\"$AXIOMA_DB_USER\"},
    {\"key\":\"ESPOCRM_DATABASE_PASSWORD\",\"value\":\"$AXIOMA_DB_PASS\"},
    {\"key\":\"ESPOCRM_DATABASE_NAME\",\"value\":\"$DB_NAME\"},
    {\"key\":\"ESPOCRM_SITE_URL\",\"value\":\"https://$DOMAIN\"},
    {\"key\":\"AXIOMA_PROFILES\",\"value\":\"$PROFILES\"},
    {\"key\":\"AXIOMA_CLIENT_ID\",\"value\":\"$CLIENT_ID\"}
]"

cap_api "/user/apps/appDefinitions/update" "POST" \
    "{\"appName\":\"$APP_NAME\",\"envVars\":$ENV_VARS_JSON}" > /dev/null


# --------------------------------------------------
# 7. Domain & HTTPS
# --------------------------------------------------
log "Step 4: Configuring Domain '$DOMAIN'..."

cap_api "/user/apps/appDefinitions/customdomain" "POST" \
    "{\"appName\":\"$APP_NAME\",\"domainName\":\"$DOMAIN\"}" > /dev/null

log "Step 5: Enabling SSL (LetsEncrypt)..."
cap_api "/user/apps/appDefinitions/enablecustomdomainssl" "POST" \
    "{\"appName\":\"$APP_NAME\",\"domainName\":\"$DOMAIN\"}" > /dev/null


# --------------------------------------------------
# 8. Deployment
# --------------------------------------------------
log "Step 6: Deploying Docker Image..."

cap_api "/user/apps/appDefinitions/update" "POST" \
    "{\"appName\":\"$APP_NAME\",\"imageName\":\"axioma-core:latest\"}" > /dev/null

# --------------------------------------------------
# 9. Completion
# --------------------------------------------------
log "=================================================="
log "Provisioning Complete!"
log "=================================================="
log "App:        $APP_NAME"
log "URL:        https://$DOMAIN"
log "Profiles:   $PROFILES"
log ""
log "NEXT STEPS:"
log "1. Verify database connectivity in App Logs."
log "2. Log into the CRM and set up the admin user."
log "=================================================="
