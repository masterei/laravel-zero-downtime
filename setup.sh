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
    log "🚀 Initializing application (Framework v$FRAMEWORK_VERSION)..."

    validate_environment
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
