#!/usr/bin/env bash

set -Eeuo pipefail

readonly APP_NAME="${1:?Usage: ./rollback.sh <app-name>}"

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/config.sh"

if [[ $EUID -eq 0 ]]; then
    fail "Do not run rollback.sh with sudo. Run it as the application owner."
fi

main() {
    select_release

    log "↩️ Starting rollback (Framework v$DEPLOY_VERSION)..."

    run_rollback_script
    activate_release

    log "✅ Rollback completed successfully."
}

select_release() {
    log "📋 Available releases..."

    local -a releases
    local release_name
    local choice
    local confirm
    local current_release

    current_release="$(readlink -f "$CURRENT")"

    mapfile -t releases < <(
        find "$RELEASES" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            | sort -r
    )

    if [[ ${#releases[@]} -eq 0 ]]; then
        fail "No releases found."
    fi

    for i in "${!releases[@]}"; do
        release_name="$(basename "${releases[$i]}")"

        if [[ "$current_release" == "${releases[$i]}" ]]; then
            printf " [%d] %s (current)\n" "$((i + 1))" "$release_name"
        else
            printf " [%d] %s\n" "$((i + 1))" "$release_name"
        fi
    done

    echo
    read -rp "Select a release to activate: " choice

    [[ "$choice" =~ ^[0-9]+$ ]] || fail "Invalid selection."

    (( choice >= 1 && choice <= ${#releases[@]} )) || fail "Invalid selection."

    RELEASE_PATH="${releases[$((choice - 1))]}"

    if [[ "$RELEASE_PATH" == "$current_release" ]]; then
        fail "The selected release is already active."
    fi

    echo
    read -rp "Rollback to '$(basename "$RELEASE_PATH")'? [y/N]: " confirm

    [[ "$confirm" =~ ^[Yy]$ ]] || {
        log "Rollback cancelled."
        exit 0
    }
}

run_rollback_script() {
    log "⚙️ Running rollback script..."

    cd "$RELEASE_PATH"

    local script=".deploy/rollback.sh"

    if [[ -f "$script" ]]; then
        bash "$script"
        log_done "⚙️ Rollback script completed."
    else
        log_done "⚙️ No rollback script found. Skipping."
    fi
}

activate_release() {
    log "↩️ Activating release..."

    ln -sfn "$RELEASE_PATH" "$BASE/current_tmp"
    mv -Tf "$BASE/current_tmp" "$CURRENT"

    log_done "↩️ Release activated."
}

trap 'fail "Rollback failed while executing: $BASH_COMMAND"' ERR

main
