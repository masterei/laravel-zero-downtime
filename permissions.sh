#!/usr/bin/env bash

set -Eeuo pipefail

readonly APP_NAME="${1:?Usage: ./permissions.sh <app-name>}"

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/config.sh"

if [[ $EUID -ne 0 ]]; then
    fail "Please run permissions.sh with sudo."
fi

main() {
    log "🔐 Repairing shared resource permissions (Framework v$FRAMEWORK_VERSION)..."

    validate_environment
    repair_env_permissions
    repair_storage_permissions
    verify_storage_permissions

    log "✅ Shared resource permissions repaired."
}

validate_environment() {
    log "🔍 Validating environment..."

    local required_commands=(
        setfacl
        getfacl
    )

    for command in "${required_commands[@]}"; do
        command -v "$command" >/dev/null 2>&1 \
            || fail "Missing command: $command"
    done

    [[ -d "$SHARED/storage" ]] \
        || fail "Storage directory does not exist."

    [[ -f "$SHARED/.env" ]] \
        || fail ".env file does not exist."

    log_done "🔍 Environment validated."
}

repair_env_permissions() {
    log "📄 Repairing .env permissions..."

    chown "$APP_OWNER:$APP_OWNER" "$SHARED/.env"
    chmod 640 "$SHARED/.env"

    log_done "📄 .env permissions repaired."
}

repair_storage_permissions() {
    log "📁 Repairing storage permissions..."

    chown -R "$APP_OWNER:$APP_OWNER" "$SHARED/storage"

    setfacl -Rm "u:$RUNTIME_USER:rwX,u:$APP_OWNER:rwX" "$SHARED/storage"
    setfacl -Rdm "u:$RUNTIME_USER:rwx,u:$APP_OWNER:rwx" "$SHARED/storage"

    log_done "📁 Storage permissions repaired."
}

verify_storage_permissions() {
    log "🔍 Verifying storage permissions..."

    local test_file="$SHARED/storage/.acl-test"

    touch "$test_file"

    local acl
    acl="$(getfacl "$test_file")"

    rm -f "$test_file"

    grep -q "user:$RUNTIME_USER:rwx" <<<"$acl" \
        || fail "Storage ACL inheritance failed for '$RUNTIME_USER'."

    grep -q "user:$APP_OWNER:rwx" <<<"$acl" \
        || fail "Storage ACL inheritance failed for '$APP_OWNER'."

    log_done "🔍 Storage permissions verified."
}

trap 'fail "Permissions failed while executing: $BASH_COMMAND"' ERR

main
