#!/usr/bin/env bash

set -Eeuo pipefail

readonly APP_NAME="${1:?Usage: ./setup.sh <app-name>}"

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/config.sh"

if [[ $EUID -ne 0 ]]; then
    fail "Please run setup.sh with sudo."
fi

main() {
    log "🚀 Initializing application (Framework v$DEPLOY_VERSION)..."

    validate_environment
    validate_php_version
    create_directory_structure
    initialize_shared_resources
    configure_permissions

    log "✅ Application initialized successfully."

    print_next_steps
}

validate_environment() {
    log "🔍 Validating environment..."

    local required_commands=(
        php
        tar
        setfacl
        getfacl
    )

    for command in "${required_commands[@]}"; do
        if ! command -v "$command" >/dev/null 2>&1; then
            fail "Missing command: $command"
        fi
    done

    log_done "🔍 Environment validated."
}

validate_php_version() {
    log "🐘 Validating PHP version..."

    local required="$PHP_VERSION"
    local current

    current=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')

    if [[ "$(printf '%s\n%s\n' "$required" "$current" | sort -V | head -n1)" != "$required" ]]; then
        fail "PHP $required or later is required. Current version: $current."
    fi

    log_done "🐘 PHP $current verified."
}

create_directory_structure() {
    log "📁 Creating directory structure..."

    if ! id "$APP_OWNER" >/dev/null 2>&1; then
        fail "Application owner '$APP_OWNER' does not exist."
    fi

    mkdir -p \
        "$RELEASES" \
        "$SHARED/storage"

    chown -R "$APP_OWNER:$APP_OWNER" "$BASE"

    log_done "📁 Directory structure created."
}

initialize_shared_resources() {
    log "📄 Preparing shared resources..."

    touch "$SHARED/.env"

    chown "$APP_OWNER:$APP_OWNER" "$SHARED/.env"
    chmod 640 "$SHARED/.env"

    log_done "📄 Shared resources initialized."
}

configure_permissions() {
    log "🔐 Configuring storage permissions..."

    setfacl -Rm "u:$RUNTIME_USER:rwX,u:$APP_OWNER:rwX" "$SHARED/storage"
    setfacl -Rdm "u:$RUNTIME_USER:rwx,u:$APP_OWNER:rwx" "$SHARED/storage"

    log_done "🔐 Storage permissions configured."
}

print_next_steps() {
    cat <<EOF

Next steps:

1. Copy your production environment file
   → $SHARED/.env

2. Copy your persistent storage
   → $SHARED/storage

3. Run your deployment workflow.

EOF
}

trap 'fail "Setup failed while executing: $BASH_COMMAND"' ERR

main
