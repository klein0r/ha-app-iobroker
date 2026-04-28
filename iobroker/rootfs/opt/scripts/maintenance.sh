#!/bin/bash
# Called by the ioBroker js-controller UpgradeManager when running in Docker.
#
# The UpgradeManager calls this script in two phases:
#   maintenance.sh on    -- before upgrade: block s6 restart, stop controller
#   maintenance.sh off   -- after upgrade:  re-enable s6 restart, bring service up
#
# The s6 finish script for the iobroker longrun service checks for
# NO_RESTART_FLAG and exits 125 (no restart) while the flag is present.

set -euo pipefail

MODE="${1:-}"
FLAGS="${2:-}"
NO_RESTART_FLAG="/tmp/.iobroker_no_restart"
HEALTHCHECK_FILE="/opt/.docker_config/.healthcheck"
S6_SERVICE_DIR="/run/service/iobroker"

log() { echo "[maintenance] $*"; }

case "${MODE}" in
    on)
        log "Enabling maintenance mode (flags: ${FLAGS:-none})."
        echo "maintenance" > "${HEALTHCHECK_FILE}"
        touch "${NO_RESTART_FLAG}"

        if [[ -d "${S6_SERVICE_DIR}" ]]; then
            log "Stopping controller via s6."
            s6-svc -d "${S6_SERVICE_DIR}" || true
        else
            log "Stopping controller by name (pkill)."
            pkill -TERM -f "iobroker.js-controller" 2>/dev/null || true
        fi

        sleep 5
        ;;
    off)
        log "Disabling maintenance mode (flags: ${FLAGS:-none})."
        rm -f "${HEALTHCHECK_FILE}"
        rm -f "${NO_RESTART_FLAG}"

        # Bring the s6 longrun back up. After finish exited 125 the service is
        # held in "wants down" state; s6-svc -u releases it.
        if [[ -d "${S6_SERVICE_DIR}" ]]; then
            log "Signalling s6 to restart iobroker service."
            s6-svc -u "${S6_SERVICE_DIR}" || true
        else
            log "Warning: s6 service directory not found at ${S6_SERVICE_DIR}."
        fi
        ;;
    *)
        echo "Usage: maintenance.sh on [-kbn] | off [-y]" >&2
        exit 1
        ;;
esac
