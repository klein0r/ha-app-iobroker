#!/bin/bash
# Upgrades the ioBroker js-controller safely inside the running container.
#
# Delegates to maintenance.sh (the same script the UpgradeManager calls when
# triggered via the Admin UI), so both paths share identical stop/start logic.
#
# Usage (from a shell opened via "docker exec" or the HA terminal add-on):
#   bash /opt/ha-iobroker/update-self.sh

set -euo pipefail

IOB_USER="iobroker"
MAINTENANCE="/opt/scripts/maintenance.sh"
TIMEOUT_SECONDS=60

log()  { echo "[update-self] $*"; }
fail() { echo "[update-self][ERROR] $*" >&2; exit 1; }

[[ -x "${MAINTENANCE}" ]] || fail "${MAINTENANCE} not found or not executable."

log "Enabling maintenance mode and stopping controller..."
"${MAINTENANCE}" on -kbn

log "Waiting for controller process to exit (max ${TIMEOUT_SECONDS}s)..."
elapsed=0
while pgrep -f "iobroker.js-controller" > /dev/null 2>&1; do
    if [[ ${elapsed} -ge ${TIMEOUT_SECONDS} ]]; then
        "${MAINTENANCE}" off -y || true
        fail "Controller still running after ${TIMEOUT_SECONDS}s — upgrade aborted."
    fi
    sleep 2
    elapsed=$(( elapsed + 2 ))
done
log "Controller stopped after ${elapsed}s."

log "Running 'iobroker upgrade self'..."
gosu "${IOB_USER}" iob upgrade self

log "Upgrade complete. Re-enabling maintenance mode and restarting controller..."
"${MAINTENANCE}" off -y

log "Done. The controller is starting up again."
