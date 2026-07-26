# Manus research prompt — Can standard Rails 8 + SQLite take our concurrent write load? ("pure Rails")

*Drop the section below into Manus. Operator pastes; output returns as `docs/research/PureRails.md`.*
*Bundle with: docs/research/rails8_architecture.md, RailsRustSqlite.md, RailsEventStore.md, FastRailsTest.md.*

---

## Context (concrete, technical)

Single-node **Rails 8 + SQLite** app, **Puma single process, `threads 4, 8`**, WAL mode,
`busy_timeout = 5000`. It serves an HTTP tool endpoint that ~3–20 worker processes hit with
frequent small writes (row INSERT/UPDATE + an event-log INSERT): heartbeats, status records,
claim/lifecycle transitions. Tens of writes/sec aggregate.

**Symptom:** under concurrent load it wedges — simple single-row writes block **5–26s** and
throw `ActiveRecord::StatementTimeout: SQLite3::BusyException: database is locked`, cascading
until unresponsive. Idle is fine.

**Measured / ruled out** (so answers don't re-tread these):
- A pure-AR single-row `UPDATE` (no extension, no extra work) still blocked ~5.2s under load.
- No single SQL statement is >=1s; the slow ones are *victims* waiting on the write lock.
- Single Puma process; WAL on; `busy_timeout=5000` confirmed applied.
- An in-process global Ruby mutex around the hottest writers cut holds 26s→~5s but is leaky:
  any un-wrapped writer re-opens the SQLite write-lock collision.
- Conclusion: irreducible **SQLite single-writer contention** — N Puma threads (each its own
  connection) racing one SQLite writer → `busy_timeout` thrash.

We can fix it with a custom (Rust) single-writer service, but first: **can standard Rails 8 +
mainstream gems carry this write concurrency on one node?** Want the boring, well-supported,
sourced answer.

## Questions, priority order

### Tier 1 — the knobs

1. **Puma thread count vs SQLite single writer.** For a SQLite-backed Rails 8 app, what is the
   right `threads` setting?
   - Does a LOW thread count (e.g. `threads 1,1` or `2,2`) eliminate the write-lock thrash by
     serializing at the pool — and what does it cost (read concurrency, head-of-line blocking
     on slow requests, Puma queue depth)?
   - Is there a rule of thumb tying Puma threads (and `WEB_CONCURRENCY` workers) to what one
     SQLite writer can sustain? What do 37signals / the Rails-8 SQLite guidance actually
     recommend for threads + pool on a write-heavy single DB?
   - Single process+many threads vs multiple Puma workers each 1–2 threads — which is better
     for SQLite write contention, and why?

2. **SQLite write config that actually removes busy_timeout thrash (2025–2026).** Best-practice
   values + rationale: `journal_mode=WAL`, `synchronous`, `busy_timeout` vs a real
   `busy_handler`, `IMMEDIATE`/`BEGIN CONCURRENT` transactions, `wal_autocheckpoint`,
   `journal_size_limit`, `mmap_size`, `cache_size`, `transaction_mode`. What did Stephen
   Margheim's `activerecord-enhanced-sqlite3` / the merged Rails-8 adapter changes actually
   fix about concurrent writes (the `retries` / `IMMEDIATE` transaction defaults)? Does the
   enhanced adapter already serialize writes safely?

3. **Single-writer chokepoint in pure Rails — which is idiomatic + production-real?** Rank with
   sources:
   - (a) Pin ALL writes to ONE dedicated connection (multi-DB `connects_to`) so SQLite never
     sees concurrent writers.
   - (b) `litestack` / litedb — does its SQLite handling beat vanilla for single-node write
     concurrency?
   - (c) Route mutations through Solid Queue processed by ONE worker (serialized write lane) —
     viable for SYNCHRONOUS request/response where the caller needs the result?
   - (d) Just (1)+(2) and accept N writers — is tuning alone enough at tens-of-writes/sec?

4. **Throughput ceiling.** With best-practice config, roughly how many concurrent writers /
   writes-per-second can ONE Rails-8 SQLite node sustain before busy_timeout thrash? Where is
   the line past which a dedicated single-writer service becomes unavoidable? (Numbers/benchmarks.)

### Tier 2 — off-request + alongside graph

5. **Async/off-request writes.** Push high-frequency low-value writes (per-call audit log,
   heartbeats) to Solid Queue fire-and-forget so they leave the request write path — but does
   Solid Queue, being SQLite-backed, just add to the SAME write contention? If so, separate
   SQLite DB (multi-DB) for the queue? Best practice.

6. **RDF/SPARQL alongside, OFF the relational writer.** Pure-Rails options for a graph that
   doesn't contend with the AR write lock: Oxigraph as a separate process over HTTP
   (Ruby client maturity, latency); or a separate SQLite DB for triples written async. Is
   "AR is operational truth; graph is an eventual rebuildable read-model" the pragmatic Rails
   answer in 2026?

## Ground truth

- Single node; Rails 8 Solid stack preferred (no Redis/Sidekiq).
- ActiveRecord must keep working; agent calls are synchronous (caller waits for the write).
- Prefer boring, maintained idioms with dated 2025–2026 sources. If pure Rails genuinely can't
  reach the needed write concurrency, say so and name the threshold.
