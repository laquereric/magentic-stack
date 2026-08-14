# app-osi-8-nooa-poc

A proof of concept for **OSI Level 8 — Profile 2 (reference-passing for agents)**.
Two OCI containers form a pod:

- **BACK** (`back/`) — a **Rails API** app: the authoritative, sole writer of canonical
  data. It publishes a typed method surface and speaks JSON-RPC-LD (`/rpc`).
- **FRONT** (`front/`) — a **Python** (Flask) NOOA-style harness + a small web UI. It
  reads Context **by reference** (bounded previews + `@id`), dereferences on demand, and
  pushes a **typed Effect** back to BACK.

```
  browser UI  ──▶  FRONT (Python harness)  ──JSON-RPC-LD─▶  BACK (Rails API, sole writer)
     provider + API key           reads previews by @id, pushes typed Effect
```

## The UI

The FRONT serves one page with a **pull-down to choose the LLM provider**
(Stub / Anthropic / OpenAI / Gemini) and an **API-key input box**. "Run agent" drives
the full Level-8 loop and shows the trace.

## The loop (Profile 2)

1. `methods.list` — BACK publishes its **API surface** (methods + the closed Effect shape).
2. `canonical.pull` — returns **bounded previews + `@id`s** (Context by reference; payloads stay in BACK).
3. `canonical.get` — **dereference on demand** by `@id`.
4. The model produces a **structured Effect** (a `Task` record). The LLM call is pluggable
   (`front/app.py:call_provider`); the POC ships a deterministic stub so the loop runs
   without credentials.
5. `syncIntent.push` — the Effect is validated against the **closed shape**, checked for
   `operationId` idempotency and `baseVersion` concurrency, applied, and a **signed receipt**
   is returned.

## Run

```bash
docker compose up --build
# open http://localhost:8080
```

## Status

Scaffold POC. The FRONT UI + the FRONT/BACK Level-8 loop are implemented end-to-end with a
stub "model". Real provider calls (`call_provider`) and container-build verification are the
next step. BACK keeps canonical state in memory for the POC; a real BACK persists to SQLite.

See the spec: https://github.com/laquereric/osi-level-8/blob/main/docs/osi-level-8-profile-2-nooa.md
