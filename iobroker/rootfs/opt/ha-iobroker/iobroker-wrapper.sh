#!/usr/bin/env bash
# Drop-in replacement for /opt/iobroker/iobroker.
#
# The upstream "iobroker" CLI internally uses sudo to switch to the iobroker
# user. Inside the container we have gosu instead - this wrapper keeps the
# same UX while routing privilege changes through gosu, and it blocks the
# few commands that don't make sense in a containerised setup.
#
# Adapted from buanet/ioBroker.docker/debian12/scripts/iobroker.sh.

set -euo pipefail

readonly IOB_USER="iobroker"
readonly IOB_JS="/opt/iobroker/node_modules/iobroker.js-controller/iobroker.js"

run_iob() {
    if [[ "$(id -u)" -eq 0 ]]; then
        exec gosu "${IOB_USER}" node "${IOB_JS}" "$@"
    else
        exec node "${IOB_JS}" "$@"
    fi
}

block_in_container() {
    echo "Command '$1' is blocked because ioBroker runs inside a Home Assistant app container."
    echo "Restart the app from the UI instead."
    exit 1
}

case "${1:-}" in
    fix|"node fix")
        echo "Running the ioBroker fixer is not supported inside this app."
        echo "Reinstall the app or switch to a newer image version instead."
        exit 1
        ;;
    diag)
        if [[ "$(id -u)" -eq 0 ]]; then
            curl -sLf https://iobroker.net/diag.sh -o /tmp/iob_diag.sh
            bash /tmp/iob_diag.sh | gosu "${IOB_USER}" tee "/opt/iobroker/iob_diag.log"
        else
            echo "Run 'iob diag' as root (use 'docker exec -u 0 ...' or open a root shell)."
            exit 1
        fi
        ;;
    start|stop|restart)
        # The bare verb (no adapter argument) controls the controller itself,
        # which s6 owns. Adapter-scoped variants are still allowed.
        if [[ -z "${2:-}" ]]; then
            block_in_container "iob $1"
        fi
        run_iob "$@"
        ;;
    m|maint|maintenance)
        # Maintenance mode aliases, mirroring the buanet iobroker.sh convention.
        # Shift the alias away so maintenance.sh receives on/off as $1.
        # Must run as root because maintenance.sh calls s6-svc to control the
        # service supervision directory, which requires root access.
        if [[ "$(id -u)" -ne 0 ]]; then
            echo "Run 'iob maintenance' as root (use 'docker exec -u 0 ...' or open a root shell)."
            exit 1
        fi
        shift
        exec bash /opt/scripts/maintenance.sh "$@"
        ;;
    *)
        run_iob "$@"
        ;;
esac
