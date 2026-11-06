FROM node:22-bookworm-slim

ENV HOME=/data \
    XDG_CONFIG_HOME=/data/.config \
    XDG_DATA_HOME=/data/.local/share \
    XDG_CACHE_HOME=/data/.cache \
    OPENCODE_DISABLE_AUTOUPDATE=true

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git bash curl python3 make g++ \
    && rm -rf /var/lib/apt/lists/*

# Official OpenCode npm distribution installs the Linux-native CLI.
RUN npm install --global opencode-ai

WORKDIR /data/workspace
EXPOSE 4096

# Railway supplies PORT; local Docker uses 4096.
CMD ["sh", "-lc", "exec opencode serve --hostname 0.0.0.0 --port \"${PORT:-4096}\""]
