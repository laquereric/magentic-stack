# OSI Level 8 — Reference POCs

Two runnable proof-of-concept **pods**, one per profile. Each is a **FRONT** +
**BACK** in OCI containers, built and run with **Docker Desktop** (Compose v2).

```
poc/
  profile-1/   The Cyborg Channel (three-ledger local-first sync)
    front/  back/  docker-compose.yml
  profile-2/   Reference-passing for agents (NOOA)
    front/  back/  docker-compose.yml
```

## Prerequisites

- **Docker Desktop** running (its bundled `docker compose` is all you need).

## Profile 1 — The Cyborg Channel (`profile-1/`)

Three-ledger, local-first sync. A Python **FRONT** keeps a **canonical mirror**, a
**sync_intent** outbox, and a **private_local** store; a Rails-API **BACK** is the
sole writer. Shows: pull canonical down, make edits offline (queued in the outbox),
keep private notes that never sync, and push changes up with `baseVersion`
optimistic locking + `operationId` idempotency.

```bash
cd profile-1
docker compose up --build
# then open http://localhost:8081
```

## Profile 2 — Reference-Passing for Agents (`profile-2/`)

A NOOA-style Python **FRONT** reads a 5-year sales dataset **by reference** from a
Rails-API **BACK**, answers questions (e.g. “Are sales seasonal?”), and writes
shape-validated **Effects** (Insights, and a %-change pivot table). The UI has an
LLM-provider pull-down and an API-key box (Stub works with no key).

```bash
cd profile-2
docker compose up --build
# then open http://localhost:8080
```

## Stop

From the profile folder: `docker compose down`. Both pods can run at once — the
FRONTs use different host ports (8081 and 8080); the BACKs are internal.
