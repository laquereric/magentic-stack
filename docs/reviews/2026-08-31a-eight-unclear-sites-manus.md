<!--
Source: Manus cloud agent, task 9B8HegrEHP9UpPNnSrnkD2
Commissioned 2026-08-31 on operator instruction, against the gap 63 census
(docs/architecture/GAP63_CENSUS.md) and ADR 0054.

Manus had NO repository access. Every site, line number and quoted comment came
from our brief, which was taken from grok's census. Its "not established"
markings are correct and deliberate -- in particular it does not know what our
callers do with U1 and U4, and says so rather than guessing.

STATUS: recommendation. Nothing authorized. The 8 UNCLEAR sites are unchanged.
-->

# Making Failure and Legitimate Emptiness Observable Without Breaking Callers

## Scope and evidentiary rule

This recommendation uses only the facts in the supplied census brief. There is no repository access. Any statement about callers, deployment topology, available telemetry, persistence guarantees, or exact migration counts beyond the quoted census is **not established**.

The accepted doctrine remains unchanged: boundaries do not raise into callers; they return an explicit success or refusal shape. The recommendation below adds observability and, where the caller’s behavior is unsafe, changes the boundary contract in a compatibility-preserving way.

> “A refusal that has never been seen must be distinguishable from no refusal having occurred.”

That requirement rules out logging or printing as the sole mechanism. It also requires a durable or externally monitored observation path whose absence can itself be surfaced.

## Executive recommendation

Adopt one small, owned result protocol with two layers:

1. **A typed semantic result for boundaries whose callers must make a different decision.** It must distinguish success, legitimate empty, and refusal, and carry a stable reason plus safe context. This is a contract change at U2, U3, U5, U6, and U7.
2. **A refusal-observation event for boundaries where existing caller behavior is safe and only detection is missing.** This preserves the old return value and records a structured event through a durable or externally monitored sink. This is the minimum change for U1, U4, and U8, subject to the caller-safety caveat described below.

Do not use a Ruby sentinel as the primary protocol. A sentinel can preserve a local Ruby call shape, but it is easy to miss with truthiness, equality, serialization, or cross-language clients. Do not use an out-parameter: it is non-idiomatic at a boundary, creates aliasing and lifecycle problems, and does not solve durable observation. A per-call context is useful metadata, not a semantic replacement for an explicit result.

The owned result should be a plain data envelope rather than a dependency:

```text
{ ok: true, value: ... }
{ ok: true, empty: true, value: ... }   # when empty is meaningful and must be explicit
{ ok: false, reason: "...", because: "...", event_id: "..." }
```

The exact Ruby class/module name, serialization format, event transport, and existing seam shape are **not established**. The envelope is deliberately composed only of hashes, booleans, strings, numbers, arrays, and null-like values so that Python, JavaScript, and Rust can consume it. The cost of owning it is a small implementation, tests for invariants, serializers, compatibility adapters, documentation, and a migration gate.

## Per-site verdicts

| Site | Established ambiguity | Verdict | Minimum safe change | Why |
|---|---|---|---|---|
| **U1 `vv-blob/store.rb:142 has?`** | Error returns `false`; the blob legitimately does not exist. | **Observation only, provisionally.** | Preserve boolean return for existing callers. On rescue, emit a structured refusal event with operation, stable reason, correlation/event ID, and the relevant resource identity in redacted form. Make the event durable or send it to an externally monitored sink. | The brief establishes ambiguity, but not that any caller takes an unsafe action on `false`. Therefore a contract change is not proven necessary. If repository inspection shows a caller must distinguish “missing” from “backend unavailable,” promote U1 to a contract change. | 
| **U2 `rails-cpcp/idempotency.rb:59 get`** | Error returns `nil`; `nil` also means cache miss, causing re-execution. | **Contract change required.** | Add a result-returning path that distinguishes `hit`, `miss`, and `refusal`; keep the old method as a compatibility adapter only during migration. A refusal must not be treated as a miss. | Re-execution is explicitly established. A side-channel event cannot make the current caller act differently, so observation alone is insufficient. | 
| **U3 `mmg-adr/document.rb:41 YAML parse`** | Error returns `{}`; `{}` also means empty frontmatter. The next `is_a?(Hash)` check can never catch the rescued parse failure. | **Contract change required.** | Return an explicit refusal for parse failure and an explicit successful empty-frontmatter value for valid empty frontmatter. Preserve the old parser behind an adapter only for callers that have not migrated. | The brief proves a detection check is defeated. This is not merely an operator-visibility issue: the current value destroys the distinction before the next line can inspect it. | 
| **U4 `profile11/store.rb:377 persist_artifact_ar!`** | Error returns `nil`; `nil` also means nothing to persist or persistence skipped. | **Observation only, provisionally.** | Preserve the return shape if callers do not need to react. Emit a structured refusal event on error, including the artifact operation and a correlation/event ID. | The brief does not establish what callers do with `nil`, whether persistence is required for correctness, or whether a skipped persist is safe. If a caller assumes the artifact was persisted, this becomes a contract change. | 
| **U5 `graph_replay.rb:31 storable_models`** | Error returns `[]`; `[]` also means there are no Storable models. Caller then refuses with `:no_storable_models`, so discovery failure is reported as an empty catalogue. | **Contract change required.** | Distinguish discovery success with an empty catalogue from discovery refusal. Propagate the refusal reason rather than converting it to `:no_storable_models`. | The brief explicitly establishes misclassification at the caller. A side-channel cannot correct the caller’s refusal reason or decision. | 
| **U6 `projection_job.rb:66 ensure_schema!`** | Error returns `false`; `false` also means outbox is not installed. Projection proceeds without durability. | **Contract change required, highest urgency.** | Make schema assurance return an explicit success/refusal result. Projection must not proceed on refusal; it must stop, retry, or enter an explicitly named degraded path. Which of those policies is correct is **not established**. | Proceeding without durability is an explicitly established unsafe behavior. Observation without changing the contract cannot prevent it. | 
| **U7 `rails-cpcp/idempotency.rb:72 put`** | Error returns the requested value as if it was stored; this is indistinguishable from successful put. The file documents that this failure happened in production. | **Contract change required; correctness defect.** | Return explicit success only after confirmed storage, and return refusal on storage failure. Existing callers must be adapted so a refusal cannot be treated as an accepted idempotency write. Keep the old shape only as a temporary adapter that fails closed according to an agreed policy; the exact policy is **not established**. | The advertised replay-protection guarantee is false on failure. Recording the failure does not undo the caller’s belief that the value was stored and does not prevent duplicate execution. The census author’s classification of U7 as unclear is understandable methodologically, but semantically it is a refusal/correctness defect. | 
| **U8 `cpcp_adapter.rb:475 record_refusal!`** | The refusal recorder swallows its own error after a warning. The admission refusal already happened and processing proceeds correctly; only the record is lost. | **Observation-only problem, but the observer needs a stronger contract.** | Keep admission behavior non-raising. Make `record_refusal!` return an observation result, write synchronously to an independent durable journal or externally monitored sink, and expose recorder degradation to health/gating. Do not pretend a warning means the refusal was observed. | The brief establishes that admission remains correct and that only the record is lost. Therefore changing the admission contract is not required. The recorder itself must no longer collapse “recorded” and “not recorded” into the same outcome. | 

### Should any site be left exactly as it is?

**No site is established as safe to leave exactly as it is**, because all eight violate the stated observability goal. However, U1 and U4 may retain their existing caller-facing return values if inspection confirms that no caller needs to distinguish refusal from legitimate absence or skip. In that case they still need refusal observation; “unchanged” cannot mean “no event, no health signal, and no durable record.”

## U7: correctness, not merely observability

U7 is a correctness defect. The relevant guarantee is semantic: a successful return advertises that the idempotency value was stored. The quoted production comment confirms that the failure mode has occurred. If the store fails but `put` returns the requested value, the caller is permitted to rely on a fact that is false. A metric or durable refusal event would make the defect visible after the fact, but it would not restore replay protection, prevent the operation from proceeding, or tell the caller to retry, abort, or enter a non-idempotent mode.

The compatibility strategy should therefore be **additive at the public seam, not silently coercive**. Introduce a result-returning operation, migrate callers, and gate removal of the value-returning adapter. During migration, an adapter may preserve the legacy shape only if it cannot falsely report success. The precise legacy fallback behavior—returning `nil`, returning a dedicated legacy failure object, or stopping the operation—is **not established** and must be chosen from the actual caller contracts. What must not remain is “return the requested value after rescue.”

## How U8 survives its own failure

There is no mechanism that can guarantee external observation if every observer and every independent persistence path fails. That is a reliability boundary, not a Ruby idiom. The design must state its final observation point instead of creating an infinite chain of rescuing recorders.

Use a bounded chain:

| Layer | Responsibility | If it fails |
|---|---|---|
| Admission boundary | Refuses without raising and continues according to its contract. | Return the refusal result. | 
| Refusal recorder | Attempts a structured, synchronous write to an independent durable journal or monitored sink. | Returns `{ok: false, reason: "observation_failed", ...}` to its caller and increments a health/degradation signal. | 
| Health/gate | Makes recorder degradation visible to an operator or deployment gate. | The final sink’s availability is an operational dependency; its absence must be reported as such. | 
| Independent supervisor or platform | Watches the process/health surface and retains the durable record. | **Not established** which supervisor or platform exists. If none exists, the ADR’s strongest guarantee cannot be met yet. | 

A local journal is only “durable” if its durability semantics are defined and tested; the brief does not establish a filesystem, process model, or deployment platform. Likewise, a warning log is not sufficient unless the logging path is actually scraped and its loss behavior is known. The implementation should choose one primary durable/external sink and one health signal, then explicitly test sink failure. The system should not claim that U8 was observed merely because `warn` executed.

## Migration idiom and cost

The least disruptive Ruby approach is an **owned, plain-data result envelope plus compatibility adapters**. The new methods return explicit states. Existing methods remain temporarily, delegate to the new method, and preserve the old shape only where doing so cannot create an unsafe decision. Callers migrate one boundary at a time.

| Candidate | Recommendation | Reason | Cross-language status |
|---|---|---|---|
| Sentinel object | Do not use as the boundary protocol. | Preserves local arity but is fragile under truthiness, equality, serialization, and accidental leakage. | Poor fit; object identity does not cross reliably. |
| Null Object | Do not use to represent refusal. | It intentionally makes failure look usable, which repeats the defect. | Poor fit unless reduced to explicit data, at which point it is a result envelope. |
| Second return value | Acceptable only as a temporary Ruby-local adapter. | Changes arity and is easy for callers to ignore; awkward for Python/JS/Rust seams. | Poor fit as the long-term wire contract. |
| Out-parameter | Do not use. | Hidden mutation and lifecycle/aliasing complexity; does not provide durable observation. | Poor fit. |
| Per-call context | Use as supplemental metadata. | Useful for correlation/event IDs and operation context, but cannot itself encode the semantic result. | Good as metadata if serialized explicitly. |
| Owned result envelope | **Use.** | Explicit, testable, serializable, and compatible with the existing never-raise doctrine. | Good fit for Ruby, Python, JS, and Rust. |

The exact number of caller edits is **not established** because the repository and call graph are unavailable. The census establishes eight boundary sites, not eight callers. A migration gate can still be precise: enumerate each boundary’s direct callers, require each migrated caller to consume the explicit result, and fail CI if the legacy adapter is used outside an allowlist. The gate should also fail on new rescue sites that return an ambiguous sentinel or on new conversions from refusal to an ordinary empty value.

The result protocol should have invariants tested in every language seam:

| Invariant | Required test |
|---|---|
| Refusal is not success | A rescued dependency failure produces `ok: false`, never an ordinary empty value. |
| Legitimate empty is success | Empty blob/catalogue/frontmatter/optional persistence cases use an explicit successful empty representation where applicable. |
| Reasons are stable | Machine-facing `reason` values are enumerated and versioned; human detail belongs in `because` or metadata. |
| Serialization is lossless | Ruby-to-Python/JS/Rust round trips preserve `ok`, empty state, reason, and event ID. |
| Event identity is present | Every refusal observation carries a correlation/event ID, unless a documented reason makes that impossible. |
| Legacy use shrinks | CI fails when new code calls the compatibility adapter or adds an unapproved ambiguous rescue. |

## Rule for new code

The mechanically checkable rule should be:

> **A boundary rescue may not return a value that is also a valid successful answer. Every rescued path must either return an explicit refusal result or call the approved observation wrapper while preserving a caller-safe legacy contract.**

A checker can enforce this in stages. First, inventory every `rescue StandardError` and require an annotation naming one of `fallback`, `refusal`, or `compatibility_adapter`; reject unclassified rescues. Second, for refusal boundaries, require the approved result constructor or observation wrapper and a stable reason. Third, reject known ambiguous literals (`nil`, `false`, `{}`, `[]`, and the requested input value) in refusal branches unless the site has an allowlisted proof that the old caller contract remains safe and the refusal event is recorded. Fourth, require tests that plant a dependency failure and assert both the return semantics and the observation. The exact checker language and AST tooling are **not established**.

The “never seen versus none occurred” requirement also needs a liveness check, not just a code pattern. CI or integration tests should plant a refusal, verify the durable/health surface contains it, then test the observer-failure path and verify that degradation itself is surfaced. A checker alone cannot prove runtime sink durability.

## Sequencing

The recommended sequence is risk-first and separates the mechanism from the bulk migration.

| Order | Work | Reason |
|---:|---|---|
| 1 | Define the owned result envelope, stable reason vocabulary, event identity, serialization rules, and the observation contract. | U2/U3/U5/U6/U7 require a shared shape, and future Python/JS/Rust consumers require data rather than Ruby object identity. |
| 2 | Build the observation path and its health/degradation surface, then exercise its failure mode. | U8 is the observer-of-the-observer problem. Solve the bounded durability rule before relying on it for the other seven sites. |
| 3 | Fix **U6**, then **U7**, then **U2**. | U6 permits processing without durability; U7 falsely advertises replay protection; U2 can re-execute after an idempotency lookup failure. These have explicitly established unsafe behavior. |
| 4 | Fix **U3** and **U5**. | Both erase diagnostic distinctions and cause downstream checks or refusal reasons to misfire. |
| 5 | Add observation wrappers to **U1** and **U4**, after checking caller safety. | Their contract changes are not proven necessary from the brief, so preserve compatibility unless the call graph shows unsafe dependence on the ambiguous value. |
| 6 | Migrate callers incrementally, enforce the allowlist, and remove legacy adapters only after the gate proves the old shape is gone. | The exact caller count is not established; an allowlist makes progress measurable without pretending to know the count. |
| 7 | Apply the same mechanism to the 29 known refusal sites. | The eight should dictate the shared result and observation shape, but the eight should not block adding the same observation floor to already explicit refusals. |

### Does this block the 29 refusal sites?

The eight should block **designing a second incompatible mechanism**, but they need not block improving the 29 sites’ observation. The brief establishes that all 29 currently miss the ADR floor, despite already returning refusal-like outcomes. Once the envelope and observation contract are defined, the 29 can adopt it. However, the exact migration order, risk, and caller impact for each of those 29 sites are **not established**. Do not infer that their current `reason` fields, logs, or wire paths are semantically adequate; the brief says they do not meet the floor.

## Final decision

Classify **U1, U4, and U8** as observation-only changes, with U1/U4 conditional on caller-safety inspection. Classify **U2, U3, U5, U6, and U7** as contract changes. Reclassify U7 semantically as a refusal/correctness defect even though the census kept it in UNCLEAR because the current method lacks an `ok` channel. Treat U8 as a reliability problem in the observation mechanism, solved by a bounded independent durability path plus a health signal—not by raising and not by an endless chain of fallback recorders.

The key non-breaking strategy is to add explicit result-returning paths and compatibility adapters, then use a CI gate to make legacy ambiguous paths disappear. Preserve the never-raise boundary doctrine; do not preserve false success.

## References

[1]: file:///home/ubuntu/upload/pasted_content_IPq5DSNaYCNCzAKsHUHF4s.txt "User-provided census brief: Eight sites in a Ruby codebase where a failure and a legitimate empty answer share a return value"

All factual claims in this report are derived from [the supplied brief][1]. No repository facts or external sources were used.
