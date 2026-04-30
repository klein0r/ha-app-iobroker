ARG BUILD_FROM=ghcr.io/hassio-addons/debian-base:9.3.0
# hadolint ignore=DL3006
FROM ${BUILD_FROM}

# Build arguments controlling the ioBroker installation
# NODE_MAJOR mirrors the same knob the buanet image uses to pin the
# Node.js major version pulled in by the official ioBroker installer.
ARG NODE_MAJOR=22

ENV \
    DEBIAN_FRONTEND="noninteractive" \
    LANG="de_DE.UTF-8" \
    LANGUAGE="de_DE:de" \
    LC_ALL="de_DE.UTF-8" \
    TZ="Europe/Berlin"

# Set shell with pipefail so failing pipes abort the build
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Setup base
# - Installs the same prerequisite set as the official buanet image
#   (apt-utils, gosu, python3, udev, locales, ...) so ioBroker adapters
#   can build native modules and access the same OS facilities.
# - Generates de_DE.UTF-8 / en_US.UTF-8 locales.
# - Runs the official ioBroker installer with the requested Node major
#   version and a pinned Node.js source URL.
# - Calls "iobroker unsetup" to drop the build-time UUID so every
#   container instance gets its own identity on first start.
# - Snapshots the freshly installed /opt/iobroker into a tarball that
#   the s6 init service will use to seed an empty /data volume on
#   first start (the buanet "initial_iobroker.tar" trick).
# - Pins the iobroker user to UID/GID 1000 to match the conventional
#   Home Assistant add-on user mapping.
# hadolint ignore=DL3008,DL3015
RUN \
    apt-get update \
    && apt-get install -y --no-install-recommends \
        apt-utils \
        ca-certificates \
        cifs-utils \
        curl \
        file \
        gnupg \
        gosu \
        iputils-ping \
        iso-codes \
        jq \
        libatomic1 \
        locales \
        nfs-common \
        nginx \
        nano \
        procps \
        python3 \
        python3-dev \
        tar \
        tzdata \
        udev \
        vim \
        wget \
    \
    && sed -i 's/^# *\(de_DE.UTF-8\)/\1/' /etc/locale.gen \
    && sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen \
    && locale-gen \
    \
    && mkdir -p /opt/.docker_config \
    && echo "10.0.0" > /opt/.docker_config/.thisisdocker \
    && echo "true" > /opt/.docker_config/.first_run \
    && mkdir -p /opt/scripts/.docker_config \
    && echo "10.0.0" > /opt/scripts/.docker_config/.thisisdocker \
    \
    && curl -sL https://iobroker.net/install.sh -o /tmp/install.sh \
    && sed -i "s/NODE_MAJOR=[0-9]\+/NODE_MAJOR=${NODE_MAJOR}/" /tmp/install.sh \
    && sed -i 's|NODE_JS_BREW_URL=.*|NODE_JS_BREW_URL="https://nodejs.org"|' /tmp/install.sh \
    && sed -i 's/"iobroker.backitup": "stable"/"iobroker.hass": ">=2.x"/' /tmp/install.sh \
    && bash /tmp/install.sh \
    \
    && iobroker unsetup -y \
    && echo "true" > /opt/iobroker/.fresh_install \
    \
    && tar -cf /opt/initial_iobroker.tar -C / opt/iobroker \
    \
    # /data is the only persistent path in a Home Assistant add-on, so the
    # real ioBroker tree lives at /data/iobroker. The build-time install is
    # already preserved in initial_iobroker.tar; drop the directory here and
    # leave a symlink in its place. The init-iobroker oneshot seeds
    # /data/iobroker from the tarball on first start.
    && rm -rf /opt/iobroker \
    && ln -sfn /data/iobroker /opt/iobroker \
    \
    && chsh -s /bin/bash iobroker \
    && usermod --home /opt/iobroker iobroker \
    && usermod -u 1000 iobroker \
    && groupmod -g 1000 iobroker \
    && usermod -aG dialout iobroker \
    && chown root:iobroker /usr/sbin/gosu \
    \
    && mkdir -p /etc/nginx/servers \
    \
    && apt-get clean \
    && rm -rf \
        /tmp/* \
        /var/tmp/* \
        /root/.cache/* \
        /root/.npm/* \
        /var/lib/apt/lists/*

# Reset DEBIAN_FRONTEND for interactive use via "docker exec".
ENV DEBIAN_FRONTEND="teletype"

# Copy the add-on root filesystem (s6 services, scripts, config templates).
# Provides /etc/s6-overlay/s6-rc.d/init-iobroker (oneshot) and
# /etc/s6-overlay/s6-rc.d/iobroker (longrun), plus the gosu-aware iob CLI
# wrapper at /opt/ha-iobroker/iobroker-wrapper.sh.
COPY rootfs /

# Files written from the host arrive without execute bits; restore them on
# the scripts that s6 and our init logic actually invoke.
RUN chmod 0755 \
        /etc/s6-overlay/s6-rc.d/init-iobroker/run \
        /etc/s6-overlay/s6-rc.d/iobroker/run \
        /etc/s6-overlay/s6-rc.d/iobroker/finish \
        /etc/s6-overlay/s6-rc.d/init-nginx/run \
        /etc/s6-overlay/s6-rc.d/nginx/run \
        /opt/ha-iobroker/iobroker-wrapper.sh \
        /opt/ha-iobroker/update-self.sh \
        /opt/scripts/healthcheck.sh \
        /opt/scripts/maintenance.sh

# ioBroker admin UI (direct port mapping; nginx handles the Ingress path)
EXPOSE 8081

# Health check: passes through startup/maintenance states, then confirms
# the js-controller process is running.
HEALTHCHECK --interval=30s --timeout=10s --start-period=5m --retries=3 \
    CMD /opt/scripts/healthcheck.sh

# Build arguments injected by the Home Assistant add-on builder
ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_DESCRIPTION
ARG BUILD_NAME
ARG BUILD_REF
ARG BUILD_REPOSITORY
ARG BUILD_VERSION

# Labels
LABEL \
    io.hass.name="${BUILD_NAME}" \
    io.hass.description="${BUILD_DESCRIPTION}" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version="${BUILD_VERSION}" \
    org.opencontainers.image.title="${BUILD_NAME}" \
    org.opencontainers.image.description="${BUILD_DESCRIPTION}" \
    org.opencontainers.image.source="https://github.com/${BUILD_REPOSITORY}" \
    org.opencontainers.image.documentation="https://github.com/${BUILD_REPOSITORY}/blob/main/README.md" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.created="${BUILD_DATE}" \
    org.opencontainers.image.revision="${BUILD_REF}" \
    org.opencontainers.image.version="${BUILD_VERSION}"
