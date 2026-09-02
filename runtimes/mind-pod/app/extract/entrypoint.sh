#!/usr/bin/env bash
# ROLE dispatch for the single mind-pod image.
set -e
ROLE="${ROLE:-back}"
PORT="${PORT:-3000}"
echo "[entrypoint] ROLE=$ROLE PORT=$PORT DB_PATH=${DB_PATH:-db/mind_pod.sqlite3}"
case "$ROLE" in
  back)
    bundle exec rails db:prepare
    bundle exec rails db:seed || true
    exec bundle exec rails server -b 0.0.0.0 -p "$PORT"
    ;;
  front)
    # FRONT holds NO database; it talks to BACK only over /_cpcp.
    exec bundle exec rails server -b 0.0.0.0 -p "$PORT"
    ;;
  backjob)
    # Wait for BACK to create the shared DB, then reconcile forever.
    for i in $(seq 1 30); do [ -f "${DB_PATH:-db/mind_pod.sqlite3}" ] && break; sleep 1; done
    exec bundle exec ruby bin/backjob
    ;;
  vault)
    # VAULT holds no domain DB. Boot refuses missing caller tokens / master key.
    exec bundle exec rails server -b 0.0.0.0 -p "$PORT"
    ;;
  config)
    # CONFIG is the operator UI (ADR 0046). DBless; talks to vault over HTTP.
    # Row 15 catalogue/discovery/verify lands here later.
    exec bundle exec rails server -b 0.0.0.0 -p "$PORT"
    ;;
  shape)
    # Retrieval only. No domain DB.
    exec bundle exec rails server -b 0.0.0.0 -p "$PORT"
    ;;
  *) echo "[entrypoint] unknown ROLE=$ROLE" >&2; exit 2 ;;
esac
