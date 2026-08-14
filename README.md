# app-osi-8-nooa-poc

A proof of concept for **OSI Level 8 — Profile 2 (reference-passing for agents)**,
as a **sales-analysis agent**. Two OCI containers form a pod:

- **BACK** (`back/`) — a **Rails API**: the authoritative, sole writer. It holds a
  **5-year monthly sales dataset** (2021–2025, 60 points) and publishes a typed
  method surface; it speaks JSON-RPC-LD at `/rpc`.
- **FRONT** (`front/`) — a **Python** (Flask) NOOA-style harness + a web UI. It reads
  the dataset **by reference** (a bounded preview + `@id`), **dereferences on demand**,
  asks the selected LLM your question, and pushes a **structured Insight** back.

```
  browser UI  ──▶  FRONT (Python harness)  ──JSON-RPC-LD─▶  BACK (Rails API, sole writer)
   provider + API key + question      reads sales by @id, answers, pushes an Insight
```

## The UI

One page: a **pull-down to choose the LLM provider** (Stub / Anthropic / OpenAI /
Gemini), an **API-key box**, and a **question** (default: *“Are sales seasonal?”*).
“Run agent” shows the answer plus the full Level-8 trace.

## The loop (Profile 2)

1. `methods.list` — BACK publishes its **API surface** (methods + the closed Insight shape).
2. `canonical.pull` — returns **bounded dataset previews + `@id`** (the 60-point series stays in BACK).
3. `canonical.get` — **dereference on demand** to read the full sales series.
4. The model answers the question, grounded in the data, as a **structured Insight**
   `{question, answer, seasonal, evidence}`. The published shape is compiled into a forced
   tool so the model's decode-time output == the ingest-time closed shape. The Anthropic
   path is wired (`front/app.py:call_anthropic`); Stub computes a real analysis from the data.
5. `insight.push` — the Insight is validated against the **closed shape**, checked for
   `operationId` idempotency, stored, and a **signed receipt** returned.

Example (Stub): *“Are sales seasonal?”* → *“Yes — peak Dec (~$182k), trough Feb (~$94k),
~1.9x swing, repeating every year.”*

## Run

```bash
docker compose up --build
# open http://localhost:8080 ; pick a provider, paste a key, ask a question
```

## Status

Verified end-to-end via `docker compose up --build`: both images build, BACK boots under
Puma, the loop runs, and the Profile 2 invariants hold (idempotency; closed-shape rejects a
private/server field leaking through an Insight). The **Stub** provider works without a key.
The **Anthropic** provider is wired (structured tool-use); **OpenAI/Gemini** fall back to Stub
until wired. BACK keeps state in memory for the POC.

Spec: https://github.com/laquereric/osi-level-8/blob/main/docs/osi-level-8-profile-2-nooa.md
