# `log` — ROLE=LOG as a CPCP container

**Design only. Not built.** Nothing in this file describes a running
service. No compose, no image pin, no gem, no gate.

Companion to ADR
[0058](../adr/0058-role-log-is-the-thirteenth-container.md) (the
decision), [`ROW86_87.md`](ROW86_87.md) (the stage map against what
exists), and [`ContainerTopology.md`](ContainerTopology.md) (what
runs). Stand-in today:
`gems/rails-cpcp/lib/rails_cpcp/refusal_log.rb`.

This container **aggregates**. It is not where a refusal is first
written. If a container's only record of a refusal is the one it sent
to LOG, a refusal *about* LOG has nowhere to go. That is the regress
0058 exists to prevent.

---

## What this is

A **thirteenth logical container**, `log` / `ROLE=LOG`. Under ADR
[0047](../adr/0047-three-languages-container-boundaries-own-images.md)
it is a Rails ROLE (tenth on the shared image, unless the owner splits
the image — 0058 already named that correlated-failure bound).

It is the **governed aggregation path** for producer floors. It is not:

- the local append-only floor (that is `RefusalLog` JSONL + heartbeat
  in each producer, gap 63 / 89)
- the operation journal (ADR
  [0052](../adr/0052-the-journal-is-the-only-admission-truth.md);
  many refusals have no `operation_request_cid`)
- the outside observer that would close ADR 0054 (row 87: that
  observer stays **unnamed and unbuilt**)
- `sparqlfun`, `rag`, or `graph`

Target in 0058: **13 containers, 4 images.** `nats` later spent the
"12th container" integer on a broker (ADR 0065). `rag` and
`sparqlfun` are later claimants. Owner names the count; this file
does not.

---

## What is actually there (so this is not a wish)

Measured 2026-09-10. Stage numbers are [`ROW86_87.md`](ROW86_87.md).

| Stage | Decided | Exists |
|---|---|---|
| 1. Local append-only floor in every producer | yes | **yes.** `RefusalLog` JSONL + heartbeat. Floor under restart/chmod/first-write/SIGKILL/disk in `GAP89_FLOOR.md`. |
| 2. Bounded file batching | yes, file terms | **yes.** Explicit `rotate!` (capped generations, `floor_rotated` marker). Write path untouched. |
| 3. CPCP control-plane surface for LOG | deferred | **no.** No `log.*` methods. `status` is local inspection. |
| 4. Aggregation + durable handoff | yes | **convention only.** Per-role JSONL at `<role>/log/`, collected via volume backup. No shipper. |
| 5. Outside observer (WATCH + RETAIN outside the refuser) | explicitly unbuilt (row 87) | no, by decision |

Owner sink **2026-09-03: file handoff only.** No collector, no
exporter, **no OTLP dependency** on the path that is allowed to
build. ADR 0058 still says OTLP *may* carry volume; that is not the
sink that was chosen. This container must not pretend OTLP is
running.

---

## Floor vs aggregation (do not invert)

```
producer                  log container              outside (row 87)
────────                  ─────────────              ────────────────
construct event
append JSONL locally  →   (must not be required)
  no network
rotate! (explicit)
                          read floors from volumes
                          CPCP control plane
                          file handoff convention
                                                     WATCH + RETAIN
                                                     (unbuilt, unnamed)
```

**Invariant:** kill LOG, break the shared Rails image, fill LOG
quota, remove network, restart the producer — the producer's local
first record still exists. That test is not premature (0058). A
design that makes `RefusalLog.record` call `cpcp.log.append` as the
first write **fails this file**.

MIND and switch are not Rails. They need **their own** local floors
or they have no record when LOG is down. This document does not
invent those floors; it forbids treating LOG as theirs.

---

## OTEL is the vocabulary, not the transport, not the floor

0058: OTEL is the only log data model with first-class SDKs in Ruby,
Python, and Rust. **"Basis for a CPCP contract"** means the **shape
is derived from OTEL's log data model** (timestamp, resource,
optional trace context, severity, body, event name, attributes) —
not invented.

Ruling: **do not reformat OTEL.** An OTEL LogRecord stays an OTEL
LogRecord. SHACL constrains **new attribute keys only**. Prefer no
new keys.

What is already native: `Timestamp` / `ObservedTimestamp`,
`Resource`, `SeverityNumber` / `SeverityText`, trace context,
`Body`, event name, scope name/version.

What is actually new, and already on the floor as one key:

```
cpcp.restoration: { state_reached, inconsistency, restore_when, restore_action }
```

Omitted rather than half-filled (`RefusalLog::RESTORATION_KEYS`).
No RDF graph of log records. Gap 88 (a vocabulary we would own at
an OTEL-to-SHACL translation seam) **does not arise**.

Volume: ordinary log records do **not** go through the per-record
CPCP admitted-operation path (`operationId`, idempotency, receipts).
A seam that falls over under load is a poor place to report that
things are falling over. CPCP here is the **control plane**:
identity of methods, admission policy, refusal semantics, receipts
for the few operations that are operations.

---

## CPCP methods (stage 3 — unbuilt)

JSON-RPC-LD, never-raise. Subject `cpcp.log.rpc`. Not a domain
writer. Not a replacement for `RefusalLog.record`.

| Method | Direction | Does |
|---|---|---|
| `log.status` | pull | Aggregation view: which sources have a floor, heartbeat age, generation counts. **A missing heartbeat is not zero refusals** (indeterminate). |
| `log.sources` | pull | Declared producers and their floor paths. Empty list is `ok:true` with `n:0`, not a lie that LOG is the floor. |
| `log.rotate` | push | Ask a named source to rotate. `operationId` required. Does not append a refusal. Explicit, same as local `rotate!` — never on the write path. |

**Not registered:** `log.append` / `log.record` as admitted CPCP
writes. That would put volume on the seam 0058 forbade.

When `MM_NATS_URL` is set, NATS only (ADR 0065). HTTP is not a
fallback. LOG being down is `log_unreachable` **on the caller**,
who still has a local JSONL.

Shared Rails lineage (0058 § correlated failure): if `log` is
another ROLE on `mind-pod:latest`, a bad Rails deploy takes out LOG
and most of what it collects. The claim this container is allowed
to make is the **weaker** one:

> LOG improves aggregation, queryability and cross-role correlation
> **when the shared lineage is healthy**. It does not provide
> independent evidence that the shared lineage failed.

Write that sentence into the running service so a later reader
cannot mistake it for the 0054 final observation point.

---

## What this document will not decide

| Decision | Why it is not mine |
|---|---|
| 13 vs 14 vs LOG vs `rag` vs `sparqlfun` | topology owner; 0058 already claimed 13 |
| Own image vs tenth ROLE on `mind-pod` | correlated-failure bound; 0047 one-image-per-container is still open for Rails roles |
| OTLP exporter later vs file-handoff forever | sink already chosen file-only (2026-09-03); reversing it is an ADR, not this file |
| Name of the outside observer | row 87: leaving it unnamed is the honesty |
| MIND / switch floor implementations | producers own their first write |
| Whether `log.tail` ever exists | volume-shaped; easy to smuggle `log.append` |

---

## Gates (when it is built, not now)

- A producer write path that calls `cpcp.log.*` **before** local
  append fails the floor plant (gap 89 family).
- `log.status` with a missing heartbeat is not reported as zero
  refusals. Plant: delete heartbeat, keep JSONL.
- No `log.append` / `log.record` method on the seam. Plant: calling
  it is `unknown_operation`.
- `check_nats_exclusive.py` covers this caller.
- Zero jobs is a fail. A checker that has never been planted is not
  a gate.
