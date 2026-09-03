# Gap 74 — restoration-grade refusals, without reformatting OTEL

Measured 2026-08-31 from `356b762`. ADR 0055 clause 5, ADR 0058
ruling. Do not build LOG. No OTEL SDK. No OTEL-to-SHACL LogRecord
shape.

Owner ruling, applied to Manus's field list:

> Do not reformat OTEL. Use SHACL only for required NEW metadata.
> Prefer no new metadata.

## Classification (every Manus field)

Worked against the OTEL log data model
(https://opentelemetry.io/docs/specs/otel/logs/data-model/), not
against a summary.

| Field | Verdict | Why |
|---|---|---|
| `recorded_at` / `occurred_at` | **OTEL-NATIVE** | `ObservedTimestamp` / `Timestamp`. Our JSONL `at` is the observed time (we write at record time; we do not know a distinct occurred-at). Not renamed: renaming the floor to `timeUnixNano` would reformat it. |
| `container_id` | **DROPPED** | Resource `container.id` is native, but the exact deployment identifier is **not established** (Manus). Fabricating one is worse than omitting. |
| `component` | **OTEL-NATIVE** | Resource / our existing `source`. Already on the record. |
| `severity` | **DROPPED** | `SeverityNumber`/`SeverityText` are native. Filling ERROR for every refusal would be fabricated. Source formats that do not define severity MAY omit it. |
| `trace_id` / `span_id` | **OTEL-NATIVE, omitted** | Optional in OTEL. Never required. We have no trace context at C–F. Absent, not a zero. |
| `because` | **OTEL-NATIVE** | `Body`. Already on the record. |
| `reason` | **OTEL-NATIVE** | `EventName` (class of event), already a stable symbol. Not duplicated as a second key. |
| `schema_version` | **OTEL-NATIVE** | InstrumentationScope `version`. Emitted as `otel.scope.name` + `otel.scope.version` (`rails-cpcp/refusal-log` / `1`) from the start. |
| `operation_id` | **OTEL-NATIVE as existing convention** | Not a LogRecord field. Already optional on our floor when the call has one. Still absent rather than fabricated for C–F. Not new. |
| `method` / `source` / `kind` | **existing floor** | Already there. Map to EventName/Resource; not new keys. |
| `refusal_id` | **DROPPED** | No second copy to correlate (no metric, no span, no LOG, no event-store copy in this branch). A UUID we would own, version, and keep true with no consumer. |
| `attempt` / `retry_state` | **DROPPED** | "possibly" in the constraint; retry semantics **not established**. Most sites cannot fill them honestly. |
| restoration semantics | **NEW ATTRIBUTE, JUSTIFIED** — **one key** | See below. |

## The one new key

ADR 0055: a restoration decision needs what was attempted, what state
it reached, what is inconsistent, what would make it consistent.
OTEL does not have those.

Four names in the memo (`state_reached`, `inconsistency`,
`restore_when`, `restore_action`) collapsed to **one attribute key**
`cpcp.restoration`, a map of those four members. OTEL attributes are
arbitrary key-value; a map is an AnyValue. New metadata means a new
attribute KEY, not a new format.

Rule: the key is **absent**, or it has **all four** non-empty strings.
`RefusalLog.compact_restoration` drops a partial object rather than
write a half record. A half record is the plausible-but-wrong shape.

SHACL (`gems/rails-cpcp/shapes/cpcp-restoration.shacl.ttl`) constrains
**only that object**. There is no `otel:LogRecord` shape. That would
be the translation layer the ruling forbade.

`RestorationShape` is **excluded** from the OSI Level 8 census
(`check_shape_scope`): it constrains a log attribute, not a protocol
payload, and it lives in `rails-cpcp/shapes` rather than either shape
gem. Not the 172nd in-scope shape.

## What the JSONL is, and is not

It is still the local append-only floor (ADR 0054 / 0058). It is not
OTLP, not protobuf, not RDF. Existing field names are kept; the
mapping to OTEL is this document, not a converter.

Dispatcher `observe_envelope` still omits `cpcp.restoration`: the
envelope names `reason`/`because`, not state. Absent, not guessed.

Sites that **know** the state (publisher, blob open, idempotency
init, BACKJOB HTTP, FRONT client, SQLITE_BUSY, domain-write gate,
FRONT index/create) pass a complete restoration. Return values
unchanged.

## What this does not do

- Does not build LOG.
- Does not add an OTEL SDK or exporter.
- Does not reformat JSONL into OTLP JSON.
- Does not author an OTEL-to-SHACL LogRecord vocabulary (gap 88 does
  not arise).
- Does not close gap 65 (idempotency `put` still returns the value
  when `@db` is nil). Observation of *init* failure now carries
  restoration; the put-shaped false success is still a contract
  change.
- Does not run the failure-domain test (gap 89, queued).
