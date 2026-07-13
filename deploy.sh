#!/usr/bin/env bash

set -Eeuo pipefail

readonly APP_NAME="${1:?Usage: ./deploy.sh <app-name> <release-name> <artifact-path>}"
readonly RELEASE_NAME="${2:?Usage: ./deploy.sh <app-name> <release-name> <artifact-path>}"
readonly ARTIFACT_PATH="${3:?Usage: ./deploy.sh <app-name> <release-name> <artifact-path>}"

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/config.sh"

if [[ $EUID -eq 0 ]]; then
    fail "Do not run deploy.sh with sudo. Run it as the application owner."
fi

readonly RELEASE_PATH="$RELEASES/$RELEASE_NAME"

main() {
    log "🚀 Starting deployment..."

    ensure_artifact_exists
    ensure_app_dependencies
    ensure_unique_release
    extract_artifact
    configure_cache_permissions
    link_shared_resources
    execute_release_script
    deploy_release

    cleanup_deployment

    log "✅ Deployment completed successfully."
}

ensure_artifact_exists() {
    log "📦 Validating artifact..."

    [[ -f "$ARTIFACT_PATH" ]] || fail "Artifact not found: $ARTIFACT_PATH"

    log_done "📦 Artifact validated."
}

ensure_app_dependencies() {
    log "🔍 Validating dependencies..."

    if [ ! -f "$SHARED/.env" ]; then
        fail "Missing $SHARED/.env"
    fi

    if [ ! -d "$SHARED/storage" ]; then
        fail "Missing $SHARED/storage"
    fi

    log_done "🔍 Dependencies validated."
}

ensure_unique_release() {
    log "🛡️ Verifying release uniqueness..."

    if [ -e "$RELEASE_PATH" ]; then
        fail "Release already exists."
    fi

    log_done "🛡️ Release uniqueness verified."
}

extract_artifact() {
    log "📦 Extracting artifact..."

    mkdir -p "$RELEASE_PATH"
    tar -xzf "$ARTIFACT_PATH" -C "$RELEASE_PATH"

    log_done "📦 Artifact extracted."
}

configure_cache_permissions() {
    log "🔐 Configuring cache permissions..."

    setfacl -R -m "u:$RUNTIME_USER:rx" "$RELEASE_PATH/bootstrap/cache"
    setfacl -R -m "d:u:$RUNTIME_USER:rx" "$RELEASE_PATH/bootstrap/cache"

    log_done "🔐 Cache permissions configured."
}

link_shared_resources() {
    log "🔗 Linking shared resources..."

    ln -sfn "$SHARED/.env" "$RELEASE_PATH/.env"
    ln -sfn "$SHARED/storage" "$RELEASE_PATH/storage"

    log_done "🔗 Shared resources linked."
}

execute_release_script() {
    log "⚙️ Executing release script..."

    cd "$RELEASE_PATH"

    local script=".deploy/release.sh"

    if [[ -f "$script" ]]; then
        bash "$script"
        log_done "⚙️ Release script executed."
    else
        log_done "⚙️ No release script found. Skipping."
    fi
}

deploy_release() {
    log "🚀 Activating release..."

    ln -sfn "$RELEASE_PATH" "$BASE/current_tmp"
    mv -Tf "$BASE/current_tmp" "$CURRENT"

    log_done "🚀 Release activated."
}

cleanup_deployment() {
    log "🧹 Cleaning up..."

    find "$RELEASES" \
        -mindepth 1 \
        -maxdepth 1 \
        | sort \
        | head -n -"${RELEASES_TO_KEEP}" \
        | xargs -r rm -rf

    [[ -f "$ARTIFACT_PATH" ]] && rm -f "$ARTIFACT_PATH"

    log_done "🧹 Deployment cleanup completed."
}

trap 'fail "Deployment failed while executing: $BASH_COMMAND"' ERR

main
