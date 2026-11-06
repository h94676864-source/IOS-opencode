FROM node:22-bookworm-slim

ENV HOME=/data \
    XDG_CONFIG_HOME=/data/.config \
    XDG_DATA_HOME=/data/.local/share \
    XDG_CACHE_HOME=/data/.cache \
    OPENCODE_DISABLE_AUTOUPDATE=true \
    OPENCODE_SERVER_USERNAME=opencode

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git bash curl python3 make g++ \
    && rm -rf /var/lib/apt/lists/*

# OpenCode's Linux distribution runs in this cloud container, not on iOS.
RUN npm install --global opencode-ai

COPY docker-entrypoint.sh /usr/local/bin/opencode-entrypoint
RUN chmod 0755 /usr/local/bin/opencode-entrypoint \
    && mkdir -p /data/workspace /data/.config /data/.local/share /data/.cache

WORKDIR /data/workspace
VOLUME ["/data"]
EXPOSE 4096

HEALTHCHECK --interval=30s --timeout=8s --start-period=45s --retries=3 \
  CMD-SHELL 'curl --fail --silent --show-error --user "${OPENCODE_SERVER_USERNAME:-opencode}:${OPENCODE_SERVER_PASSWORD}" "http://127.0.0.1:${PORT:-4096}/global/health" >/dev/null || exit 1'

ENTRYPOINT ["/usr/local/bin/opencode-entrypoint"]
