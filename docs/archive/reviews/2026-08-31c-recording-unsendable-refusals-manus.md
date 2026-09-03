<!--
Source: Manus cloud agent, task K9AFqp5xBmwuN7VdARSkGB
Commissioned 2026-08-31. Six real refusals from the gap 63 census (A-F) were
supplied verbatim; the verdicts are per-case, not general advice.

Manus had NO repository access. It correctly marks as "not established" that any
particular OTEL SDK configuration writes durably to a local file or survives a
full disk, crash, permission failure or host loss.

STATUS: recommendation. Nothing authorized.
-->

# Recording a Container Refusal That Cannot Be Sent Anywhere

## Executive answer

The container should record the refusal first in a **local, append-only, structured record** whose write path has no remote peer dependency. That local record is the floor. The event store, OpenTelemetry export, metrics backend, and any future `LOG` service are higher layers and may be unavailable without making the refusal disappear.

The most important distinction is between **authoritative diagnosis** and **cheap detection**. A restoration-grade refusal belongs in a structured log record because it must describe the attempted action, the state reached, the inconsistency left behind, and the condition that would restore consistency. A metric is useful for counting and alerting, but it is not a substitute for that record. A span event is useful only when a relevant span actually exists; it cannot be the floor for the three cases that have no trace context.

OpenTelemetry should be adopted as the **common vocabulary and aggregation/export layer**, not as the unconditional floor. Its log data model supports timestamps, resource identity, optional trace context, severity, body, event name, and attributes [1]. Its current event guidance supports named occurrences inside or outside an active trace, while ordinary diagnostic records may remain regular logs [2]. Those standards do not establish that a particular SDK configuration writes durably to a local file, nor that it survives a full disk, process crash, permission failure, or host loss; those properties are **not established** by the brief or by the semantic conventions.

> **Rule:** Record a refusal where recording it does not depend on the thing it is complaining about.

## Per-case verdicts

| Case | Primary record | Metric | Span event | Recommendation and reason |
|---|---|---:|---:|---|
| **A. P6 admission denial** | Local structured refusal record; also the operation journal/event-store metadata when that journal is part of the domain operation | Yes, low-cardinality counter | Yes, if an operation span exists | The operation ID and journal make this a domain refusal with operation context. The journal is the domain record; the local record preserves diagnosis if the journal/event path is unavailable. The counter detects rate changes. The span event is worthwhile only as a trace-local view, not as the source of truth. |
| **B. Handler refusal nested inside an outer success envelope** | Local structured refusal record, plus correction of the semantic observation that the outer envelope says success | Yes | Yes, when a span exists | The inner refusal must not be hidden by the dispatcher’s outer `ok:true`. Record the refusal as its own outcome, retaining the operation and trace correlation where present. The metric detects the envelope/handler mismatch at scale; the log preserves what the handler attempted and what restoration requires. |
| **C. Async worker cannot reach the app over HTTP** | Local structured refusal record in the worker | Yes | No required; no trace exists in the stated case | This is the clearest floor case. The worker has no request and no trace, so a span event cannot be the authoritative record. Record one refusal per meaningful failed loop iteration or bounded failure episode, including retry/attempt state and the worker identity. The metric is for detection, not diagnosis. |
| **D. RDF projection publisher returns `:error` while the database row commits** | Local structured refusal record in the publisher/container | Yes | No required; no trace is stated | This is a partial-commit or projection-consistency refusal. The record must state that the database commit occurred, the projection publication returned `:error`, and what replay or reconciliation condition is required. The metric detects the rate of divergence. A span event is not recommended as a dependency because the brief says this fires in an after-save callback without trace context. |
| **E. Blob-store open fails at boot** | Local structured startup record, with boot/health state reflecting failure | Yes | No | There is no request, operation, or trace. Treat it as a startup/liveness-quality refusal, not as a trace event. Record the attempted resource, the reached startup state, and the condition for recovery. The existing heartbeat is important here because it distinguishes “the observer never ran” from “zero refusals”; the refusal record and heartbeat answer different questions. |
| **F. Idempotency-store write fails but returns the value as though stored** | Local structured refusal record, with a high-severity correctness signal | Yes | No required; no trace is stated | The record must explicitly distinguish the attempted write, the false-success return, the resulting uncertainty about stored state, and the safe restoration action. A metric is valuable for immediate detection, but the log is authoritative because the failure mode is semantic and restoration-specific. Do not let the outer successful return suppress this refusal. |

The duplication in A and B is justified only where each copy has a different job: the **local record** is the dependency-independent evidence, the **domain journal or span** is contextual representation, and the **metric** is aggregate detection. For C–F, adding a span event without a span adds no independent evidence and should not be done merely for symmetry.

## The restoration-grade refusal shape

The existing `reason` and `because` fields should remain, but they should be treated as classification and explanation rather than a complete recovery plan. The durable record should have a stable envelope with a small set of required semantic fields and a structured restoration section. The exact field names below are a proposal, not an existing fact about the repository.

| Field | Purpose |
|---|---|
| `refusal_id` | Unique identifier for this refusal occurrence, minted locally before or at the refusal boundary. |
| `recorded_at` and, where available, `occurred_at` | Distinguishes when the refusal occurred from when it was written or observed. OpenTelemetry defines both timestamp concepts for log records [1]. |
| `container_id` and `component` | Identifies the container and emitting role. The exact deployment identifiers are **not established** beyond the containers listed in the brief. |
| `reason` | Existing stable symbol. Keep it machine-queryable and versioned. |
| `because` | Existing human-readable explanation. Do not make it the only diagnostic field. |
| `operation_id` | Existing operation identifier when one exists; absent rather than fabricated for C–F unless the application already defines one. |
| `attempt` and `retry_state` | States what was attempted and whether this was an initial attempt, retry, or terminal failure. Exact retry semantics are **not established**. |
| `state_reached` | The last known committed or externally observed state. This is essential for D and F. |
| `inconsistency` | The state that may now disagree with another state or system. |
| `restore_when` | A predicate-like description of the condition under which the process is considered consistent again. |
| `restore_action` | The bounded action an operator or agent should take, such as replay, reconcile, reopen, or retry after dependency recovery. The allowed action vocabulary is **not established**. |
| `severity` | A severity reflecting impact, not merely the presence of a refusal. OpenTelemetry’s log model defines severity ranges, and its exception guidance distinguishes expected handled failures from unhandled or startup-fatal failures [1] [3]. |
| `trace_id` and `span_id` | Optional trace context; never required for a refusal record. |
| `schema_version` | Allows readers and restoration tooling to evolve without guessing. The versioning policy is **not established**. |

The record should be **self-sufficient enough to diagnose without the event store**. If a domain journal exists, the journal can contain a metadata copy or a reference, but the local record must not contain only a pointer to a record that may never be written.

## Metric plus log: the shared-key answer

Use both, but do not pretend they have equal authority. The metric should be a low-cardinality counter such as a refusal count grouped only by bounded dimensions: container/component, stable `reason`, and perhaps a bounded outcome class. It must not use `refusal_id`, `operation_id`, prose, URLs, exception messages, or other per-occurrence values as labels. The exact metric name and permitted dimensions are **not established**.

The shared correlation key is `refusal_id`. It belongs in the local record, and—when the same occurrence is represented in the event store, a span, or an exported log—it should be copied unchanged. When a domain operation already has an `operation_id`, retain both: `operation_id` joins the refusal to business work; `refusal_id` identifies this refusal occurrence. For a refusal without operation context, `refusal_id` is still available and is the local anchor. A locally minted UUID-like identifier is a recommendation; the identifier format is **not established**.

The metric should not be joined to an individual refusal by label. Its relationship is temporal and aggregate: the metric says that refusals of class `reason=X` occurred in a component; the structured record, queried by time/component/reason, supplies the restoration detail. If exact one-to-one accounting is required, that requirement is **not established** by the brief and should not be smuggled into the metric design.

Drift is controlled by making the structured refusal outcome the conceptual source object from which both emissions are derived, and by defining a one-way authority rule: **if the metric and log disagree, the local structured record wins**. A metric failure must not prevent the local record; a local-record failure must itself be surfaced through the container’s lowest available local mechanism and the heartbeat/health model. Whether a particular runtime can make two outputs atomic is **not established** and should not be assumed.

## Does OpenTelemetry provide the floor?

**No. OpenTelemetry is not the floor.** It is an appropriate cross-language schema/API and aggregation layer for the Rails/Ruby, Python, and Rust components because the brief says it is already proven in another repository and has first-class SDKs in the three languages used. That proves local organizational experience, not the durability of this repository’s eventual configuration.

The proposed layering is therefore:

| Layer | Role | May depend on a peer? | Authority |
|---|---|---:|---|
| Local per-container structured file | Dependency-independent evidence and diagnosis | No remote peer dependency | Floor and source of truth for refusal occurrence |
| Local heartbeat/health signal | Evidence that the observer/container is alive and distinguishing no observation from zero events | Not established; should be kept independent of the event bus | Availability of observation, not refusal detail |
| OpenTelemetry logs/metrics/traces | Common representation, aggregation, querying, and export | Yes, once exported to a collector/backend | Derived observability view |
| Event store/domain journal | Business metadata and operation history | Yes, where the operation depends on it | Domain record when successfully written, not universal refusal sink |

OpenTelemetry’s own guidance recognizes that SDKs/exporters may not have a chance to export errors during startup or shutdown [3]. Thus, routing every refusal only through an OTEL exporter would violate the rule already established in the brief. The local writer may itself fail for local reasons such as disk exhaustion, permissions, corruption, process termination, or host loss; those failure modes are **not established** for this deployment. “No peer dependency” must not be misrepresented as “mathematically cannot fail.”

## The proposed `LOG` service

The instinct is right: if `LOG` exists, it should be an **aggregation and query surface over container-owned records**, never the primary sink. A refusal about `LOG` would then still have a place to go—the local floor—and `LOG` could report its own outage as an observability failure rather than silently becoming the authority.

At the stated size—one pod, one agent, and a few sessions—building a sixth protocol seam is probably premature. That judgment is a recommendation, not a measured fact. First stabilize the local JSONL schema, rotation/retention policy, heartbeat distinction, and direct operator access to the files. Use existing OTEL aggregation where it already fits. Build `LOG` only when query fan-out, retention, access control, cross-container search, or durable off-container retention creates a demonstrated need.

If later justified, the smallest useful contract should be read-oriented: query by time range, container/component, `reason`, `refusal_id`, and `operation_id`; return the original record plus source-container identity and schema version; expose ingestion gaps and heartbeat state; and distinguish “no matching refusal” from “source unavailable” and “source not yet ingested.” It should not expose an application-facing “send refusal to LOG” operation as the required path. Whether CPCP imposes additional contract requirements is **not established** by the brief.

## Correlation without dependency

The originating container or boundary mints `refusal_id` locally. For operations that already have an `operation_id`, the operation owner should mint that operation ID before the operation begins and propagate it to every representation. The brief establishes that A has an operation ID; it does not establish who currently mints it, so ownership beyond this recommendation is **not established**.

The local write occurs with the refusal record and does not wait for the event store. If the event-store metadata later succeeds, it copies the same `refusal_id` and `operation_id`. If it never succeeds, the local record remains a complete evidence item. For C–F, do not invent a business operation ID merely to make a schema uniform. Use `refusal_id` as the occurrence identifier and add a worker/boot/callback context field where available.

## What must not be instrumented

Do not instrument a site merely because it returns a value other than the main path. Instrument a site only when the outcome represents a **failed, degraded, ambiguous, or externally consequential state** for which an operator or restoration agent could take a different action. An intentional fallback that completes the contract—such as a capability probe, optional-value lambda, or literal name default—does not qualify on the facts supplied.

A mechanically checkable policy is preferable to reviewer memory. Classify every censused site with a finite disposition such as `refusal`, `fallback`, or `unclear`; require every site to carry exactly one classification; require refusal sites to declare the stable `reason` and restoration fields; and require fallback sites to carry an explicit no-instrumentation marker. CI can then fail on an unclassified site, on a refusal without a record path, or on instrumentation added to a fallback-marked site. The exact Ruby AST checks, annotations, and CI integration are **not established** and are intentionally left out because the request asks for a recommendation rather than implementation.

The eight `unclear` sites should remain a review queue, not be silently converted into either refusal telemetry or fallback silence. Their final classification is **not established** by the brief.

## Recommended sequence

1. **Declare the local floor and its authority.** Make the per-container structured JSONL record the authoritative refusal evidence, with the heartbeat remaining a separate observer-health signal.

2. **Define the refusal schema before adding more signal types.** Require `refusal_id`, stable `reason`, attempted action, reached state, inconsistency, and restoration condition/action. Make trace and operation identifiers optional rather than structurally required.

3. **Instrument A–F according to the table.** Record all six locally. Add low-cardinality metrics for all six. Add span events only where a meaningful span exists and the duplicate context earns its cost; do not manufacture traces for C–F.

4. **Add the domain/event-store copy only where it is domain metadata.** For A and any equivalent operation-context case, write the business metadata when possible, but never make that write the local floor. Preserve the same `refusal_id`.

5. **Place OTEL above the floor.** Map the local record into OTEL logs and export metrics/traces for aggregation, while explicitly testing and documenting exporter loss, queue overflow, collector outage, and shutdown/startup behavior. The outcome of those tests is **not established**.

6. **Mechanize the census policy.** Keep the 11 known fallbacks out of instrumentation through explicit classifications and checks; keep the 8 unclear sites visible as unresolved classification debt.

7. **Defer `LOG`.** Revisit it only after local-file operation and OTEL aggregation reveal a concrete query, retention, or access need that justifies another seam.

The small correct design is therefore **local structured refusal records plus heartbeat, with metrics for detection and optional OTEL/event-store/span representations above them**. It is not a single universal sink, and it is not a general-purpose `LOG` service built in advance of a demonstrated need.

## References

[1]: https://opentelemetry.io/docs/specs/otel/logs/data-model/ "OpenTelemetry Logs Data Model"

[2]: https://opentelemetry.io/docs/specs/semconv/general/events/ "OpenTelemetry Semantic Conventions for Events"

[3]: https://opentelemetry.io/docs/specs/semconv/exceptions/exceptions-logs/ "OpenTelemetry Semantic Conventions for Exceptions in Logs"

[4]: https://opentelemetry.io/docs/specs/otel/trace/sdk/ "OpenTelemetry Tracing SDK"

*Prepared from the supplied brief. No repository facts were inferred; statements not derivable from the brief are identified as recommendations or **not established**.*
