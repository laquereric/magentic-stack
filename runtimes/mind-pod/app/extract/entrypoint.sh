#!/usr/bin/env bash
# ROLE dispatch for the single mind-pod image.
set -e
ROLE="${ROLE:-back}"
PORT="${PORT:-3000}"
# In-pod CPCP is NATS. HTTP binds loopback unless this container is the
# host-published operator surface (ADR 0065: HTTP is not a fallback).
HTTP_BIND="${HTTP_BIND:-127.0.0.1}"
case "$HTTP_BIND" in
  127.0.0.1|0.0.0.0) ;;
  *) echo "[entrypoint] HTTP_BIND=$HTTP_BIND must be 127.0.0.1 or 0.0.0.0" >&2; exit 2 ;;
esac
echo "[entrypoint] ROLE=$ROLE PORT=$PORT HTTP_BIND=$HTTP_BIND DB_PATH=${DB_PATH:-db/mind_pod.sqlite3} BUS_DB_PATH=${BUS_DB_PATH:-db/bus.sqlite3}"
rails_http() {
  exec bundle exec rails server -b "$HTTP_BIND" -p "$PORT"
}
case "$ROLE" in
  back)
    bundle exec rails db:prepare
    bundle exec rails db:seed || true
    rails_http
    ;;
  front)
    # FRONT holds NO database; it talks to BACK only over NATS when
    # MM_NATS_URL is set. HTTP is the browser page, not a CPCP fallback.
    rails_http
    ;;
  backjob)
    # Wait for BACK to create the shared DB, then reconcile forever.
    for i in $(seq 1 30); do [ -f "${DB_PATH:-db/mind_pod.sqlite3}" ] && break; sleep 1; done
    exec bundle exec ruby bin/backjob
    ;;
  vault)
    # VAULT holds no domain DB. Boot refuses missing caller tokens / master key.
    rails_http
    ;;
  config)
    # CONFIG is the operator UI (ADR 0046). DBless; talks to vault over NATS
    # when MM_NATS_URL is set (HTTP is not a fallback).
    rails_http
    ;;
  shape)
    # Retrieval only. No domain DB.
    rails_http
    ;;
  bus)
    # Seam + projection. Owns the BUS sqlite on the bus-data volume
    # (BUS_DB_PATH), not the domain sqlite. Migrates only the bus DB —
    # never the primary (seeds write domain rows this ROLE may not).
    bundle exec rails db:migrate:bus
    rails_http
    ;;
  persist)
    # Placement authority. Owns the PERSIST sqlite on the persist-data
    # volume (PERSIST_DB_PATH) — never the domain sqlite it places.
    # Callers are allowlisted: empty PERSIST_CALLERS fails closed at boot.
    # Migrates only the persist DB, never the primary or seeds.
    : "${PERSIST_CALLERS:?PERSIST_CALLERS must name the allowed callers}"
    bundle exec rails db:migrate:persist
    rails_http
    ;;
  rag)
    # Retrieval seam. Owns NO sqlite: the index lives in Milvus on the rag-data
    # volume, and it is a projection of text BACK already journalled. Nothing
    # to migrate, no domain store to mount.
    #
    # MILVUS_URL unset is deliberately not fatal here: rag.* then answers
    # rag_not_configured, which is a truthful refusal per request rather than a
    # boot that hides the gap.
    rails_http
    ;;
  *) echo "[entrypoint] unknown ROLE=$ROLE" >&2; exit 2 ;;
esac
