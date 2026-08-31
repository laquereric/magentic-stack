# CPCP behavioural contract

Derived from the code at `0546bf3`. SHACL is the **data** contract
(`grounding.rb:123–126`: the shapes are the specification; the Ruby is a
hand-written reproduction). This document is the **behaviour** a second
implementation would otherwise have to infer from Ruby.

Every claim cites `file:line`. Where a doc disagrees with the code, the code
wins and the doc is named.

## How to read SPECIFIED vs OBSERVED

| Mark | Means |
|---|---|
| **SPECIFIED** | A second implementation **MUST** do this. Something other than “the Ruby currently does it” says so: a seam comment that states the protocol, a test that is the fail-closed contract of `rails-cpcp`, or a SHACL-backed rule that names intent. |
| **OBSERVED** | This is what this Ruby does. Whether a second implementation must match it is **not established**. |

Marking a behaviour SPECIFIED because the code does it would turn one
implementation into a protocol. That is the failure this document exists to
avoid. Replay returning the same `receipt_cid` is the type specimen: it is
real, and it is OBSERVED until something says MUST.

Three layers are not one protocol:

| Layer | What it is | Where |
|---|---|---|
| `rails-cpcp` | JSON-RPC-LD dispatcher, envelope, `operationId` cache | `gems/rails-cpcp` |
| `rails-osi-level-8` | Shape gate, admission, receipts, a second idempotency key | `gems/rails-osi-level-8` via `CpcpAdapter.wrap` |
| mind-pod projection | Which methods exist on this BACK | `runtimes/mind-pod/app/config/initializers/rails_cpcp.rb` |

A method that is **not** wrapped (`note.get`, `reconciliation.latest`,
`l8.execution.complete`, most PULL lists) never sees L8 admission or
replay_payload. Behaviour below that says “the adapter” does not apply to
those methods.

---

## 1. Never-raise envelope

| Claim | Mark | Code |
|---|---|---|
| The dispatcher never raises across the boundary. Handler exceptions become an envelope. | **SPECIFIED** | `dispatcher.rb:3–4, 31–32`; spec `rails_cpcp_spec.rb:34–37` |
| Success is `{ok: true, result: ...}` with `jsonrpc: "2.0"` and a JSON-LD `@context`. | **SPECIFIED** (this is the success shape the engine emits and the spec asserts) | `envelope.rb:17–19`; spec `:27–31` |
| Failure is `{ok: false, error: {reason, because}}` — nested `error`, not a flat `{reason, because}`. | **SPECIFIED** at the `rails-cpcp` layer | `envelope.rb:4–5, 22–24`; README:75 |
| HTTP status of `POST /_cpcp/rpc` is always 200, including failures. | **OBSERVED** | `rpc_controller.rb:11–12` `status: :ok`. No spec asserts the status code. |
| `because` is a String at the dispatcher (`because.to_s`). | **OBSERVED** | `envelope.rb:24` |
| L8 `KnownRefusal` puts a **Hash** in `error.because`. | **OBSERVED** | `cpcp_adapter.rb:42–52`. A caller that assumes `because` is always a string will break on wrapped methods. |
| Empty body is `empty_body`. Unparseable body is `unparseable_json`. Neither is `unknown_operation`. | **SPECIFIED** | `request_body.rb`; `rpc_controller.rb:10–16`; spec `rails_cpcp_spec.rb` |
| `jsonrpc` / `@context` on the **request** are not validated. | **OBSERVED** | `dispatcher.rb:10–14` reads `method`, `params`, `id`, `operationId` only. |

Gap 49 (`COVERAGE_GAPS.md`) already records that vault answers HTTP 401/403
while CPCP answers 200 + envelope. That split is OBSERVED on two different
surfaces, not a CPCP rule.

---

## 2. Surface

| Claim | Mark | Code |
|---|---|---|
| Three routes exist under the mount: `POST rpc`, `GET cid.json`, `GET up`. | **SPECIFIED** as the engine’s surface | `gems/rails-cpcp/config/routes.rb:3–5`; README:70–72 |
| `GET /_cpcp/up` returns `{ok, cid_digest, operations}` where `operations` is the declared names. | **OBSERVED** (shape of the liveness body is not in SHACL) | `rpc_controller.rb:21–23` |
| CSRF is skipped; auth is not in the dispatcher. | **OBSERVED** | `rpc_controller.rb:4–7` |

`rails-cpcp` README:32 says co-locating FRONT and BACK in one **container** is
not a conformant CPCP deployment. mind-pod runs them as **two containers,
one image** (`ROLE=front` / `ROLE=back`). The README is not describing this
tree’s topology; it is not “wrong about the code,” it is about a different
deploy. ADR 0047 (one Rails application, many ROLEs) is the doctrine that
applies here.

---

## 3. `operationId`

| Claim | Mark | Code |
|---|---|---|
| PUSH requires an `operationId`. Empty is refused `operation_id_required`. | **SPECIFIED** | `dispatcher.rb:21–22`; spec `:40–43`; grounding `P1::SessionOpenEffectShape` at `grounding.rb:131` (“a PUSH must name its intent before performing it”) |
| PULL does not require `operationId`. | **SPECIFIED** | README:20–21; dispatcher only checks when `direction == :push` (`dispatcher.rb:21`) |
| `operationId` may sit on the envelope **or** in `params`. | **OBSERVED** | `dispatcher.rb:20`; adapter copies envelope → params at `cpcp_adapter.rb:35–39` |
| How a caller **derives** the id (UUID, digest, …) is not constrained. | **not established** | backjob uses `"backjob-#{SecureRandom.uuid}"` (`runtimes/mind-pod/app/bin/backjob:16`). That is one caller, not the protocol. |
| L8 `request_cid` is `cid:sha256:` of a canonical JSON of `{operation, operationId, title, body, idempotencyKey}`. | **OBSERVED** | `cpcp_adapter.rb:236–243`; `cid.rb:10–14` |

Same `operationId` is “a retry”; a different id is “a different intent”
(README:22–23). The retry **body** is the replay document in §5.

---

## 4. `idempotencyKey` / `idempotencyScope`

There are **two** caches. They do not use the same key.

### 4a. Dispatcher cache (`rails-cpcp`)

| Claim | Mark | Code |
|---|---|---|
| PUSH is looked up by **`operationId` only** before the handler runs. A hit returns `Replay.from_first_result(cached)`, not the frozen first body. | **SPECIFIED** | `dispatcher.rb:23–25`; `replay.rb` |
| The cache is pluggable; default is in-process memory. | **OBSERVED** (and the file says where a receipt lives is “a property of the deployment and not of the protocol”) | `idempotency.rb:9–10, 79` |
| A receipt “MUST OUTLIVE THE PROCESS THAT ISSUED IT.” | Comment-level MUST on the **store**, not a wire rule. Default `MemoryIdempotency` **does not**. After process restart the same `operationId` writes again. | `idempotency.rb:17–24` |
| sqlite store uses `INSERT OR IGNORE`; first receipt wins; never raises. | **OBSERVED** | `idempotency.rb:30–32, 63–74` |
| mind-pod never assigns `SqliteIdempotency`. | **OBSERVED** | no `idempotency_store=` outside the gem spec |

### 4b. L8 request table (`CpcpAdapter`, wrapped PUSH only)

| Claim | Mark | Code |
|---|---|---|
| Adapter copies `operationId` onto `idempotencyKey` if the caller omitted the key. | **OBSERVED** | `cpcp_adapter.rb:37–38, 103–105` |
| Scope defaults to `"default"`. | **OBSERVED** | `cpcp_adapter.rb:103` |
| Replay at this layer is `find_by(operation_name, idempotency_scope, idempotency_key, admission_status: "admitted")`. | **OBSERVED** | `cpcp_adapter.rb:246–254` |
| `l8.execution.complete` uses scope `"complete"` and key `idempotencyKey` or `"complete:#{op_cid}"`. | **OBSERVED** | `p7_commands.rb:123–130` |

`idempotencyScope` / `idempotencyKey` are **not** in `rails-cpcp`. They exist
only once L8 wraps the handler. Unwrapped PUSH (`l8.execution.complete` is
unwrapped — `rails_cpcp.rb:114–116`) still has the dispatcher `operationId`
cache **and** its own SQL find.

---

## 5. Replay — one shape

**SPECIFIED:** a PUSH replay (dispatcher `operationId` cache hit, or L8
table hit) returns one document, not a frozen copy of the first success:

```
{ "replayed": true, "receipt_cid"?, "outcome_cid"?,
  "operation_request_cid"?, "replayed_from_receipt_cid"? }
```

Missing cids are omitted, not nulled (`replay.rb` `.compact`). First
success stays domain-shaped (`governance.replayed` is still false on that
first body — it is not a replay).

| Path | Who answers | Result |
|---|---|---|
| A | dispatcher cache, same `operationId` | `Replay.from_first_result(cached)` |
| B | L8 `admitted` table, same idempotency key | `CpcpAdapter#replay_payload` → same helper |
| C | `l8.execution.complete` SQL | already `{replayed:true, receipt_cid, outcome_cid, ...}` |

**OBSERVED:** cid *identity* across retries (same `receipt_cid` as the first
write) is still how this Ruby finds the prior row. A second implementation
must emit `replayed: true` in this shape; it is not required to reuse the
same cid bytes unless it is this store.

backjob logs `result.slice("receipt_cid", "outcome_cid")` — those keys
remain on the complete replay. It does not read `replayed`.

---

## 6. `receipt_cid` and `outcome_cid`

| Claim | Mark | Code |
|---|---|---|
| L8 receipt cid is `cid:sha256:` of a canonical JSON payload that includes status, domain, and `operation_request_cid`. | **OBSERVED** | `cpcp_adapter.rb:299–303`; `cid.rb:10–14` |
| First wrapped PUSH attaches `governance.receipt_cid` on the domain result. | **OBSERVED** | `cpcp_adapter.rb:213–220` |
| `outcome_cid` is minted by P7 `outcome_record!`, not by `rails-cpcp`. | **OBSERVED** | `p7_commands.rb:192–207` |
| Complete-replay `outcome_cid` is “latest Outcome for that operationRequestCid”, not necessarily the one minted with that receipt. | **OBSERVED** | `p7_commands.rb:129` `order(determined_at: :desc).first` |
| What a caller may **rely on**: not established beyond “this Ruby puts these keys on these results.” | **not established** | — |

P4::DurableReceiptShape is unbound (`grounding.rb:112–117`): “no response to
constrain.” Receipt shape is **not** a SHACL-enforced wire contract today.

---

## 7. Method registry

| Claim | Mark | Code |
|---|---|---|
| The set of methods is whatever `RailsCpcp.project` registered in this process. | **OBSERVED** | `registry.rb:28–33`; advertised at `rpc_controller.rb:22–23` |
| Unknown `method` → `ok: false`, `reason: unknown_operation`. | **SPECIFIED** | `dispatcher.rb:15`; spec `:34–37` |
| Direction is `:pull` or `:push` at declaration; other values raise at boot. | **SPECIFIED** for this engine’s DSL | `registry.rb:18–19` |
| Which names mind-pod serves. | **OBSERVED** (deployment, not protocol) | `rails_cpcp.rb` — Notes (`note.list/get/create`), `reconciliation.latest`, `l8.*` PULL/PUSH, `ux.*`, `meaning.*`, `intent.*` |

There is no closed method list outside that initializer. A second BACK
MUST fail closed on names it did not declare. It MUST NOT be required to
declare this tree’s `ux.*` / `meaning.*` catalogue.

`note.get` and `reconciliation.latest` are **unwrapped** (`rails_cpcp.rb:19–20,
43–44`): no inbound shape, no admission row, `RecordNotFound` becomes
`handler_error` via `dispatcher.rb:31–32`.

---

## 8. Error taxonomy

**SPECIFIED** (dispatcher, string `reason`):

| `reason` | When |
|---|---|
| `unknown_operation` | `Registry.find` miss (`dispatcher.rb:15`) |
| `missing_params` | declared `params` minus request keys (`dispatcher.rb:17–18`) |
| `operation_id_required` | PUSH with empty operationId (`dispatcher.rb:22`) |
| `handler_error` | `StandardError` in an **unwrapped** handler (`dispatcher.rb:31–32`) |

**OBSERVED** (L8 `KnownRefusal.reason`, not a closed enum in `rails-cpcp`):

`grounding_refused`, `processing_failed`, `operation_id_required` (again, from
the adapter), `invalid_params`, `unknown_operation_request`, plus Profile 9/11
strings (`UX_*`, `MEANING_*`, `meaning.*`). Produced at
`cpcp_adapter.rb:82, 97, 105` and throughout P7/P9/P11.

Extra params are allowed (`op.params - params.keys`; missing only).
**OBSERVED.**

`because` type: see §1.

---

## 9. Admission and the shape gate

Wrapped PUSH sequence (`cpcp_adapter.rb:70–192`):

1. Inbound `Grounding.validate` against `request_shape`.
2. If it fails: `AdmissionAttempt` with `conforms: false` (`record_refusal!`,
   `:476–477, 454–473`). **No** `OperationRequest`. Raise `grounding_refused`.
3. Else: `find_prior_request` → possible replay (§5 path B).
4. `AdmissionAttempt` `conforms: true`.
5. `OperationRequest.create!(admission_status: "admitted")` (`:257–275`).
6. Journal: received, grounded.
7. `Authorization.admit!` (P6). Deny: journal `refused`, re-raise. **The
   OperationRequest row stays `admission_status: "admitted"`.** See defects.
8. Routing evidence, handler (domain write), `ExecutionReceipt`, P5, …
9. **Outbound** `Grounding.validate` against `response_shape` **last**, after
   the write (`:165–190`). Failure journals `response_refused` and raises;
   the write and receipt already exist so a retry takes path B.

PULL validates only the response (`:195–207`). No admission row.

`OperationRequest` allows `admission_status` `admitted|refused`
(`operation_request.rb:20`) but **create always uses `admitted`**. Grounding
refusals live on `AdmissionAttempt`, not on `OperationRequest`.

**SPECIFIED:** inbound shape failure refuses the PUSH (grounding.rb module
comment + adapter raise). **OBSERVED:** everything about *where* that
refusal is stored, P6-after-admit, and outbound-after-write.

“Admitted” means: an `OperationRequest` row exists with
`admission_status: "admitted"`. It does **not** mean P6 permitted or that
the response shaped. That gap is OBSERVED and is a defect for P6 deny.

---

## 10. Ordering and concurrency

| Claim | Mark | Code |
|---|---|---|
| Journal `sequence` is `maximum(:sequence) + 1` per operation request. | **OBSERVED** | `cpcp_adapter.rb:280` |
| No lock around that increment. | **not established** that it is safe under concurrent PUSH | — |
| Memory idempotency Hash is not synchronised. | **OBSERVED** | `idempotency.rb:12–14` |
| sqlite `INSERT OR IGNORE` makes first writer of a key win. | **OBSERVED** | `idempotency.rb:69` |
| Cross-request ordering (total order of note.create vs complete, etc.). | **not established** | no code states one |

---

## 11. Docs that disagree with the code

| Doc | Says | Code |
|---|---|---|
| `rails-cpcp` README:77 (updated) | Retries return one replay document | Matches `dispatcher.rb` + `replay.rb`. |
| Session instruction / some callers: flat `{ok, reason, because}` | Flat failure | `envelope.rb:22–24` is nested `error: {reason, because}`. Code wins. |
| `grammar/cpcp/README.md` | CPCP shapes are a pending subtree import; conformance is the gem specs | Matches: there is still no behavioural spec in `grammar/cpcp/`. This file is that gap (row 14). |

---

## Defects found while reading

1. ~~Two replay bodies~~ **closed** — one replay document (`replay.rb`).
2. ~~Invalid JSON is `unknown_operation`~~ **closed** — `empty_body` /
   `unparseable_json`.
3. ~~P6 deny leaves `admission_status: "admitted"`~~ **closed** by ADR 0052.
4. ~~Dispatcher retry reports `replayed: false`~~ **closed** with (1).

---

## What could not be determined

- Whether a second implementation must reuse the **same** `receipt_cid`
  bytes on replay (this Ruby does; the MUST is only the replay document).
- Required HTTP status for a refused envelope (200 is OBSERVED).
- Required `because` type (String vs Hash).
- Whether a second implementation must persist the dispatcher cache across
  process restart. The comment says a receipt must; the default store does
  not; the protocol note says store location is deployment.
- Concurrency / total order.
- Whether unwrapped methods (`note.get`, `l8.execution.complete`, …) are
  allowed to stay unshaped, or that is unfinished wrapping.
- A closed error-reason enum that includes L8 / P9 / P11 strings.
- What `cid.json` obliges a caller to do besides advertise operations
  (`cid.rb:9–28`).
- Vault’s future CPCP edge (ADR 0046 amendment 2): this document is the
  behaviour that edge would inherit; it does not specify vault.
