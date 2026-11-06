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

mkdir -p "$HOME/workspace" "$XDG_CONFIG_HOME/opencode" "$XDG_DATA_HOME" "$XDG_CACHE_HOME"

# Give every new session a usable primary agent. A model is only selected when
# the operator supplies a real, provider-qualified model ID via OPENCODE_MODEL.
# Never invent provider credentials or overwrite an existing user's config.
CONFIG_FILE="$XDG_CONFIG_HOME/opencode/opencode.json"
export CONFIG_FILE
node <<'NODE'
const fs = require("node:fs");
const path = process.env.CONFIG_FILE;
const requestedModel = (process.env.OPENCODE_MODEL || "").trim();

let config = {};
if (fs.existsSync(path)) {
  try {
    config = JSON.parse(fs.readFileSync(path, "utf8"));
    if (!config || Array.isArray(config) || typeof config !== "object") {
      throw new Error("config root must be an object");
    }
  } catch (error) {
    console.error("WARNING: Existing OpenCode config could not be parsed; leaving it untouched:", error.message);
    process.exit(0);
  }
}

if (!config.default_agent) config.default_agent = "build";
if (requestedModel) {
  if (!requestedModel.includes("/") || requestedModel.startsWith("/") || requestedModel.endsWith("/")) {
    console.error("WARNING: OPENCODE_MODEL must use provider/model-id format; ignoring invalid value.");
  } else {
    config.model = requestedModel;
  }
}

const output = JSON.stringify({ "$schema": "https://opencode.ai/config.json", ...config }, null, 2) + "\n";
fs.writeFileSync(path, output, { mode: 0o600 });
console.log("OpenCode defaults ready: default_agent=" + config.default_agent +
  (config.model ? ", model=" + config.model : ", model awaits provider setup"));
NODE

echo "Starting authenticated OpenCode server on 0.0.0.0:$PORT"
exec opencode web --hostname 0.0.0.0 --port "$PORT"
