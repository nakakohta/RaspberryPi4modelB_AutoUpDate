#!/usr/bin/env bash
set -Eeuo pipefail

PATH=/usr/sbin:/usr/bin:/sbin:/bin

LOG_FILE=/var/log/apt-auto-maintenance.log
LOCK_FILE=/var/lock/apt-auto-maintenance.lock
REBOOT_REQUIRED=/var/run/reboot-required

timestamp() {
    date '+%Y-%m-%d %H:%M:%S%z'
}

if [[ "${EUID}" -ne 0 ]]; then
    printf '[%s] ERROR: This script must be run as root.\n' "$(timestamp)" >&2
    exit 1
fi

exec >>"${LOG_FILE}" 2>&1

log() {
    printf '[%s] %s\n' "$(timestamp)" "$*"
}

if ! command -v flock >/dev/null 2>&1; then
    log "ERROR: flock command not found."
    exit 1
fi

exec 9>"${LOCK_FILE}"
if ! flock -n 9; then
    log "Another apt-auto-maintenance process is already running; exiting."
    exit 0
fi

run_step() {
    local description=$1
    shift

    log "START: ${description}"
    if "$@"; then
        log "DONE: ${description}"
    else
        local status=$?
        log "ERROR: ${description} failed with exit code ${status}."
        return "${status}"
    fi
}

main() {
    log "APT auto maintenance started."

    run_step "apt-get update" apt-get update
    run_step "apt-get full-upgrade -y" env DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y
    run_step "apt-get autoremove -y" env DEBIAN_FRONTEND=noninteractive apt-get autoremove -y

    if [[ -e "${REBOOT_REQUIRED}" ]]; then
        log "${REBOOT_REQUIRED} exists; rebooting now."
        reboot
    else
        log "No reboot required."
    fi

    log "APT auto maintenance completed."
}

main "$@"
