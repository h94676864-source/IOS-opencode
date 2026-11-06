#!/bin/sh
set -eu

: "${PORT:=4096}"
: "${OPENCODE_SERVER_USERNAME:=opencode}"
export PORT OPENCODE_SERVER_USERNAME

if [ -z "${OPENCODE_SERVER_PASSWORD:-}" ]; then
  echo >&2 "FATAL: OPENCODE_SERVER_PASSWORD must be set before starting OpenCode."
  exit 64
fi

if [ "${#OPENCODE_SERVER_PASSWORD}" -lt 16 ]; then
  echo >&2 "FATAL: OPENCODE_SERVER_PASSWORD must contain at least 16 characters."
  exit 64
fi

case "$PORT" in
  *[!0-9]*|'') echo >&2 "FATAL: PORT must be a numeric TCP port."; exit 64 ;;
esac
if [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
  echo >&2 "FATAL: PORT must be between 1 and 65535."; exit 64
fi

mkdir -p "$HOME/workspace" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME"
echo "Starting authenticated OpenCode server on 0.0.0.0:$PORT"
exec opencode web --hostname 0.0.0.0 --port "$PORT"
