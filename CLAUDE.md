# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A **Home Assistant add-on** that packages [ioBroker](https://www.iobroker.net/) so it runs as a supervised container under Home Assistant OS / Supervisor.

The add-on wraps the **official ioBroker installer** (`https://iobroker.net/install.sh`) on top of `ghcr.io/hassio-addons/debian-base`, mimicking the pattern used by the well-known [buanet/iobroker](https://github.com/buanet/iobroker) Docker image so adapters that expect a "real" ioBroker install keep working.

## Repository layout

- [iobroker/Dockerfile](iobroker/Dockerfile) — single source of truth for the image. Most edits land here.
- [iobroker/config.yaml](iobroker/config.yaml) — Home Assistant add-on manifest (slug, ingress, ports, supported archs).
- [iobroker/build.yaml](iobroker/build.yaml) — per-arch base-image map consumed by the HA add-on builder.
- [iobroker/rootfs/](iobroker/rootfs/) — overlay copied into the image via `COPY rootfs /`. Holds the s6-overlay v3 service tree under `etc/s6-overlay/s6-rc.d/` plus the `iob` CLI wrapper at `opt/ha-iobroker/iobroker-wrapper.sh`.

There is no source code beyond the Dockerfile and the rootfs shell scripts — no Node/Python project, no test suite, no lint config.

## Runtime service model (s6-overlay v3)

The base image (`hassio-addons/debian-base`) ships s6-overlay as PID 1 and the add-on manifest sets `init: false` so s6 owns process supervision. Two services live under [iobroker/rootfs/etc/s6-overlay/s6-rc.d/](iobroker/rootfs/etc/s6-overlay/s6-rc.d/):

- [`init-iobroker`](iobroker/rootfs/etc/s6-overlay/s6-rc.d/init-iobroker/run) — oneshot, runs as root. Ports steps 1–4 of the upstream [buanet `iobroker_startup.sh`](https://github.com/buanet/ioBroker.docker/blob/main/debian12/scripts/iobroker_startup.sh) to the HA add-on world. Seeds `/data/iobroker` from `/opt/initial_iobroker.tar` on first start, swaps in the gosu-aware `iob` CLI, resets ownership, runs `iob setup first` when `.fresh_install` is present, and syncs the ioBroker hostname with the container hostname.
- [`iobroker`](iobroker/rootfs/etc/s6-overlay/s6-rc.d/iobroker/run) — longrun, depends on `init-iobroker`. `exec gosu iobroker node controller.js`, so SIGTERM reaches the controller directly; `timeout-kill` (60s) bounds graceful shutdown before s6 sends SIGKILL.

Both services are wired into the default `user` bundle via empty marker files in `s6-rc.d/user/contents.d/`. A failed oneshot blocks the longrun, which is the behaviour we want — no point running the controller against an un-initialised data dir.

## Persistence model

`/data` is the only persistent path in a HA add-on, so the runtime ioBroker tree lives at `/data/iobroker`. The Dockerfile removes the build-time `/opt/iobroker` directory after creating the seed tarball and replaces it with a symlink `/opt/iobroker → /data/iobroker`, so all the absolute paths baked into ioBroker scripts and adapter configs keep working. The `init-iobroker` oneshot extracts `/opt/initial_iobroker.tar` into `/data` (with `--strip-components=1`) when `/data/iobroker` is missing or empty.

## What was deliberately not ported from buanet

The HA add-on intentionally drops several buanet features — either because HA already provides them or because they belong on a later iteration:

- **SETUID/SETGID** — UID/GID are pinned to 1000 at build time.
- **AVAHI** — Home Assistant has its own discovery layer.
- **Multihost / external states & objects DB** — advanced, not exposed via add-on options yet.
- **USBDEVICES chown loop** — use the add-on `devices:` field in [config.yaml](iobroker/config.yaml) instead.
- **`PACKAGES` / `PACKAGES_UPDATE`** — image is what it is; rebuild to change it.
- **Userscripts (`/opt/userscripts`)** — could be reintroduced via an `addon_config` mount later.

## Build & run

The add-on is normally built by the Home Assistant Supervisor or the `home-assistant/builder` action; locally you can build the image directly:

```bash
# Build for the host arch
docker build \
  --build-arg BUILD_FROM=ghcr.io/hassio-addons/debian-base:9.3.0 \
  --build-arg BUILD_ARCH=amd64 \
  -t local/ha-iobroker \
  iobroker/

# Run with a persistent data volume (mirrors the HA add-on /data mount)
docker run --rm -it -p 8081:8081 -v iobroker-data:/data local/ha-iobroker
```

Admin UI is exposed on `8081` and surfaced through HA Ingress (`ingress: true`, `ingress_stream: true` in [config.yaml](iobroker/config.yaml)).

When iterating on the Dockerfile, watch for hadolint failures — the file has explicit `# hadolint ignore=` pragmas (`DL3006`, `DL3008`, `DL3015`) and CI lints it.

## Architecture notes that aren't obvious from one file

- **Node.js major version is a build arg.** `ARG NODE_MAJOR=20` is patched into the upstream `install.sh` via `sed` before execution; this matches the buanet image's knob. Bumping Node means changing this arg, not editing the installer.
- **Pinned Node source URL.** The Dockerfile rewrites `NODE_JS_BREW_URL` in `install.sh` to `https://nodejs.org` so the build does not rely on the installer's default mirror.
- **`iobroker unsetup -y` runs at build time** to drop the build-time UUID. Without this, every container instance would advertise the same ioBroker host UUID.
- **First-boot seeding via tarball.** After install, `/opt/iobroker` is snapshotted into `/opt/initial_iobroker.tar`, then the build-time directory is removed and replaced with a symlink to `/data/iobroker`. The `init-iobroker` oneshot extracts the tar into `/data` (with `--strip-components=1`) on first start so `/opt/iobroker` (the symlink) resolves to a real tree. This is the same trick the buanet image uses, adapted to HA's `/data`-only persistence; preserve both halves when modifying the rootfs or the Dockerfile.
- **Marker files.** `/opt/.docker_config/.thisisdocker`, `/opt/.docker_config/.first_run`, `/opt/scripts/.docker_config/.thisisdocker`, and `/opt/iobroker/.fresh_install` are read by ioBroker's own scripts to detect "running inside Docker" and "needs first-run setup." Do not delete these.
- **UID/GID 1000 for `iobroker`.** Matches the conventional HA add-on user mapping so bind-mounted `/data` is writable. Changing this will break existing installs.
- **Locales `de_DE.UTF-8` + `en_US.UTF-8`, TZ `Europe/Berlin`.** Hard-coded German defaults (the maintainer is German); some adapters parse localized strings, so changing these defaults can have surprising downstream effects.
- **`host_network: true`** in [config.yaml](iobroker/config.yaml) — required because many ioBroker adapters do LAN discovery (mDNS, broadcast, etc.). The `8081/tcp` port mapping coexists with host networking for clarity in the HA UI.
