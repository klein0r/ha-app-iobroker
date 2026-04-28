# Maintenance & Manual Operations

This page covers tasks that require stopping the js-controller temporarily
without restarting the container — for example, running `iob setup custom` or
upgrading the js-controller manually from a shell.

## How the stop/start mechanism works

The add-on uses [s6-overlay v3](https://github.com/just-containers/s6-overlay)
as its process supervisor. The `iobroker` service is a **longrun**: s6 restarts
it automatically whenever `controller.js` exits.

To prevent an unwanted restart during maintenance, the
`/opt/scripts/maintenance.sh` script sets a flag file
(`/tmp/.iobroker_no_restart`) before stopping the controller. A `finish` script
on the s6 service checks for that file and exits `125`, which tells s6 not to
restart the service. When maintenance is complete, `maintenance.sh off` removes
the flag and signals s6 to bring the service back up.

The same script is called automatically by the ioBroker **UpgradeManager**
(Docker image version ≥ 8.1.0) when a js-controller upgrade is triggered from the
Admin UI:

```
maintenance.sh on -kbn   # before upgrade: stop controller, block restart
maintenance.sh off -y    # after upgrade:  re-enable restart, bring service up
```

---

## Opening a shell in the running container

All commands below require a shell inside the container. Use one of:

```bash
# Option A – HA SSH & Terminal add-on (or any SSH access to the host)
docker exec -it $(docker ps -qf name=iobroker) bash

# Option B – Home Assistant CLI (from the host)
ha addon exec local_iobroker bash
```

---

## Entering maintenance mode manually

```bash
/opt/scripts/maintenance.sh on
```

This blocks s6 from restarting the controller but **does not stop** the running
process. Stop it explicitly afterwards:

```bash
gosu iobroker iob stop
# Wait a few seconds for the process to exit cleanly.
```

Or combine both in one step (mirrors what the UpgradeManager does):

```bash
/opt/scripts/maintenance.sh on -k
# The -k flag sends SIGTERM to controller.js immediately.
```

While maintenance mode is active the Docker health check reports
`Maintenance mode active` (exit 0) rather than checking for the controller
process, so the container is not marked unhealthy.

---

## Leaving maintenance mode

```bash
/opt/scripts/maintenance.sh off
```

This removes the restart lock and signals s6 to bring the `iobroker` service
back up. The controller starts within a second or two; watch the add-on log in
the Home Assistant UI to confirm.

---

## Example: running `iob setup custom`

`iob setup custom` configures the ioBroker database connection interactively. It
must not run while the controller is active.

```bash
# 1. Stop the controller and block s6 restart
/opt/scripts/maintenance.sh on -k
sleep 5   # allow graceful shutdown

# 2. Run the interactive setup
gosu iobroker iob setup custom

# 3. Re-enable the service
/opt/scripts/maintenance.sh off
```

---

## Upgrading the js-controller manually

> **Preferred path:** use the **Update** button in the ioBroker Admin UI.
> With Docker image version ≥ 8.1.0 the UpgradeManager handles the full stop → upgrade
> → restart cycle automatically via `maintenance.sh`.

If you need to perform the upgrade from a shell (e.g. because the Admin UI
button is not yet available or the upgrade failed mid-way), use the helper
script shipped with the add-on:

```bash
bash /opt/ha-iobroker/update-self.sh
```

The script:
1. Calls `maintenance.sh on -kbn` to block s6 restart and stop the controller.
2. Waits up to 60 seconds for the controller process to exit.
3. Runs `iob upgrade self`.
4. Calls `maintenance.sh off -y` to re-enable and start the controller.

No container restart is required.

### Manual step-by-step variant

If you prefer to run each step explicitly:

```bash
# 1. Enter maintenance mode and stop the controller
/opt/scripts/maintenance.sh on -k
sleep 10

# 2. Confirm the controller is no longer running
pgrep -a -f controller.js || echo "Controller stopped."

# 3. Upgrade the js-controller
gosu iobroker iob upgrade self

# 4. Re-enable the service
/opt/scripts/maintenance.sh off
```

Watch the add-on log in the Home Assistant UI to confirm the new version starts
successfully.

---

## Troubleshooting

### Controller does not restart after `maintenance.sh off`

If `s6-svc -u` had no effect (the service directory was not found at startup
time), restart the add-on from the Home Assistant UI. The flag file is stored in
`/tmp/`, which is cleared on every container restart, so the controller will
start normally.

### Maintenance mode is stuck after a container crash

Because the flag file lives in `/tmp/`, it is automatically removed on container
restart. No manual cleanup is needed.
