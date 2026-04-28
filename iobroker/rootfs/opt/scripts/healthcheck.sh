#!/bin/bash
set -euo pipefail

HEALTHCHECK_FILE="/opt/.docker_config/.healthcheck"

if [[ -f "${HEALTHCHECK_FILE}" ]]; then
    state="$(cat "${HEALTHCHECK_FILE}")"
    case "${state}" in
        starting)
            echo "Startup in progress"
            exit 0
            ;;
        maintenance)
            echo "Maintenance mode active"
            exit 0
            ;;
    esac
fi

if pgrep -f "iobroker.js-controller" > /dev/null 2>&1; then
    echo "js-controller is running"
    exit 0
fi

echo "js-controller is not running"
exit 1
