#!/bin/sh
# Shape D: pin on loopback :4000, Node leftover on :8789 / :8790.
# 4000 is not published. MIND keeps calling http://switch:8789/v1.
set -eu

ADAPTER_DIR=$(dirname "$0")
CONFIG_OUT="${SWITCHYARD_CONFIG:-/tmp/switchyard.toml}"
PIN_HOST="${SWITCHYARD_PIN_HOST:-127.0.0.1}"
PIN_PORT="${SWITCHYARD_PIN_PORT:-4000}"

# inject_env.mjs prints export lines; values come from /state (bind mount).
eval "$(node "$ADAPTER_DIR/inject_env.mjs")"
node "$ADAPTER_DIR/generate_config.mjs" --out "$CONFIG_OUT"

switchyard-server \
  --config "$CONFIG_OUT" \
  --host "$PIN_HOST" \
  --port "$PIN_PORT" &

exec node /switch/server.mjs
