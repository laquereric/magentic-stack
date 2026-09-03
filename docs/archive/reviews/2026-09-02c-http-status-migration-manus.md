---
title: "CPCP Migration Plan: Moving from Always-200 HTTP to an Explicit Status Contract"
topic: http-status-migration
group: status-migration
source: manus
manus_task_url: https://manus.im/app/JDcTDUdTF4h8tCNCDRVqEx
note: Authored by the Manus cloud agent; facts reflect its web research and are not independently verified.
---

# CPCP Migration Plan: Moving from Always-200 HTTP to an Explicit Status Contract

## Scope and method

This brief is a migration decision, not a survey. It operates on the measured CPCP seam and the in-tree patterns described in the census and constraints. It uses RFC 9110 for HTTP semantics and the JSON-RPC 2.0 specification as boundary references. When standards do not dictate a mapping, the recommendation is a CPCP policy decision expressed in the migration contract.

The proposed change applies to POST /_cpcp/rpc, currently served by a Rails controller that renders status: :ok at four sites. The in-tree surface includes five callers: three Ruby callers using Net::HTTP that parse res.body unconditionally (never inspecting status), and two Python callers using bare urllib.request.urlopen, which raise HTTPError on 4xx and do not read the body from the exception path. The Ruby callers are expected to survive the status change unchanged; the Python files are the primary client work.

The refusal envelope is never-raise: {ok:true, ...} or {ok:false, reason:, because:}. Refusal vocabulary includes grounding refusals (SHACL validation at admission), admission refusals (authorization evidence denied), outbox_not_installed, outbox_schema_check_failed, durability unreadiness, graph_unreachable, sqlite_busy, idempotency_not_durable, and vault-side unauthenticated / not_allowlisted / secret_absent.

## Executive summary

- Adopt a dual-signalling contract: preserve the conforming CPCP envelope in the response body and have the HTTP status describe the transport/outcome of the exchange. JSON-RPC 2.0 provides transport-agnostic semantics but does not supply an HTTP status mapping; the mapping is a CPCP policy.
- Maintain domain refusals that result from a completed RPC evaluation as HTTP 200, provided those refusals are outcomes of the RPC method rather than HTTP-layer failures. This includes a grounding refusal and an admission decision denied by authorization evidence, if those are truly domain outcomes.
- Use 422 Unprocessable Content for a well-formed JSON-RPC request whose contained CPCP instructions fail SHACL validation, per RFC 9110 semantics; prioritize this when the failure is semantic rather than syntactic.
- Use 401 for missing or invalid authentication credentials (include WWW-Authenticate); use 403 for authenticated-but-not-permitted access when the decision is a domain-level denial rather than an HTTP-layer failure. Do not reuse 404 as a generic domain refusal.
- Use 500 for server-side invariant or configuration defects; use 503 for temporary unavailability of a dependency or capacity constraint. Retry-After should be added only when a meaningful delay is known and a safe replay policy exists; 503 must not be treated as a general permissive signal for retries of non-idempotent operations.
- Fix Python callers in parallel with the server change: the helper must read the body on HTTPError, preserve the envelope, and expose transport status separately from ok/reason.
- Roll out with a per-profile flag and/or per-method opt-in, enabling safe seam-by-seam migration rather than a single controller-wide flip. CI gates should validate both client readiness and a defensible mapping contract.

## 1. Status mapping: the contract to implement

The status column is the CPCP mapping. The standards basis column distinguishes RFC 9110-derived semantics from CPCP policy. Retryable indicates CPCP-level guidance rather than a universal HTTP rule.

| Refusal class or condition | HTTP status | Standards basis | Retryable | Notes |
|---|---:|---|---|---|
| grounding refusal (payload failed SHACL validation at admission) | 200 (recommended for domain outcome) | RFC 9110 422 Unprocessable Content supports semantics where content is understood but cannot be processed; 422 is a standards-backed signal for semantic failure within a syntactically valid request; JSON-RPC 2.0 defines the envelope but not HTTP mapping [1][2] | No generic retry | Domain outcome: keep transport outcome aligned with a method result; debate between 200-as-domain-outcome and 422-as HTTP-semantics; if chosen, document the profile clearly |
| admission refusal (authorization evidence denied) | 200 (recommended for domain outcome) | RFC 9110 403 covers understood-but-refused requests; 401 covers missing/invalid credentials; CPCP policy determines whether this maps to 200 as a domain decision or uses 403 for access-control failures [1] | No generic retry | If the decision is that the RPC was evaluated but refused due to domain policy, 200 may be defensible; otherwise use 403 with documented boundary |
| vault-side unauthenticated (no valid credentials) | 401 | RFC 9110 401 Unauthorized with WWW-Authenticate | No automatic retry with same credentials | Preserve envelope; include WWW-Authenticate; retries only after credential renewal |
| vault-side not allowlisted or not permitted | 403 | RFC 9110 403 Forbidden | No retry with same credentials | Use explicit boundary between resource access and domain refusal |
| vault-side secret absent (missing secret required for authentication) | 401 if missing credential; otherwise 500/503 depending on server configuration | RFC 9110 401 for missing credentials; server config semantics fall to CPCP policy | No generic retry | Distinguish credential absence from server misconfiguration; include source in envelope |
| not-found target/resource (often an undisclosed or absent route) | 404 | RFC 9110 404 Not Found; cacheability defined (§4) | No generic retry | Distinguish resource absence from domain refusal; consider Cache-Control guidance |
| malformed HTTP/JSON request (pre-RPC parse issues) | 400 | RFC 9110 400 Bad Request | No retry unless the request is corrected | Treat as HTTP-layer issue; not a domain decision |
| well-formed content; SHACL/semantic rejection (domain-level invalid CPCP content) | 422 | RFC 9110 422 Unprocessable Content | No automatic retry | SHACL failures treated as domain outcomes if they reflect a business rule; 422 aligns with semantic invalidity |
| outbox_not_installed (durability component missing) | 500 | RFC 9110 500 Internal Server Error | No automatic retry by default; 503 if temporary outage is known | Treat as deployment/configuration fault; do not repeatedly retry a non-idempotent operation |
| outbox_schema_check_failed (durability invariant violated) | 500 | RFC 9110 500 | No automatic retry | Deployment-invariant violation; escalate |
| graph_unreachable (dependency unavailable) | 503 | RFC 9110 503 Service Unavailable | Conditional retry via Retry-After when the outage is known to be temporary | Use Retry-After only with a known recovery window and safe idempotent/replay semantics |
| graph_unreachable upstream invalid response | 502 | RFC 9110 502 Bad Gateway | Not automatically retryable | Retry only under explicit safety constraints |
| graph_unreachable timeout | 504 | RFC 9110 504 Gateway Timeout | Not automatically retryable | Retry only with a safe, deduplicated plan |
| sqlite_busy (transient DB lock) | 503 (default) or 500 (if invariant) | RFC 9110 503 for temporary conditions | Conditional retry; avoid replaying non-idempotent operations |
| idempotency_not_durable (durable replay guarantees unavailable) | 503 | RFC 9110 503 for temporary inability; 500 for invariant failure | No automatic retry; require a safe replay policy | Avoid silent retry loops; provide explicit retry policy |
| unexpected server exception | 500 | RFC 9110 500 | No automatic retry | Logs and correlation IDs required |

Binding decisions and unresolved boundary:
- The mapping is not “all domain failures are 200.” The rule is that CPCP keeps 200 only for an intentionally completed RPC method whose result is a domain decision. Endpoint failures (authentication, authorization failures, missing resources, malformed requests, infrastructure issues) use HTTP error statuses. The boundary about whether every admission/refusal is a domain decision versus an endpoint-auth failure is NOT ESTABLISHED from the supplied facts and must be classified in the envelope with a dedicated field (failure_layer: domain|http_auth|http_request|infrastructure).

## 2. What RFC 9110 says, what JSON-RPC says, and what CPCP infers

RFC 9110 provides the semantics of HTTP status codes and notes Retry-After semantics and cacheability across the status code classes. It defines 400 (Bad Request), 401 (Unauthorized), 403 (Forbidden), 404 (Not Found), 409 (Conflict), 422 (Unprocessable Content), 500 (Internal Server Error), 502 (Bad Gateway), 503 (Service Unavailable), 504 (Gateway Timeout), and 505 (HTTP Version Not Supported), as well as the Retry-After header semantics [RFC 9110]. JSON-RPC 2.0 defines the transport-agnostic request/response/error model and does not prescribe an HTTP status mapping [JSON-RPC 2.0 Specification]. The CPCP migration uses RFC 9110 to ground HTTP semantics, while the mapping decisions themselves are application policy decisions made under CPCP.

The 400 vs 422 distinction is important: RFC 9110 supports 422 for well-formed content that cannot be processed due to semantic constraints, while 400 covers syntactic problems or invalid framing. JSON-RPC 2.0 does not constrain this mapping; the mapping is an application-layer decision in CPCP.

## 3. Client and server sequencing

Python callers must be updated before or concurrently with the server status change. Their common helper must read the body on HTTPError, preserve the envelope, and expose status separately from ok/reason. The three Ruby callers do not necessarily require changes to survive 4xx, since Net::HTTP returns a response object; however, tests should assert proper handling of non-2xx statuses. The Rails controller should migrate from four unconditional status render sites to a single mapping engine that emits a typed outcome and a status selected from the mapping table. The in-tree vault pattern should be treated as a compatibility baseline rather than copied verbatim.

A safe intermediate rollout is to enable a server-side flag, for example CPCP_HTTP_STATUS_PROFILE=dual-v1, with a header CPCP-HTTP-Status-Profile: dual-v1 to allow canarying and rollback. If per-method opt-in is feasible, begin with read-only or idempotent methods, then extend to writes after tests pass.

Recommended release sequence
- Release 1: Contract freeze – publish the status mapping table, failure-layer classifications, retry rules, header and cache policies, and a version/profile identifier.
- Release 2: Client readiness – update Python clients to expose status-aware wrappers; update Ruby clients to respect the new mapping; add tests for a representative set of statuses.
- Release 3: Server mapping behind a flag – implement a single mapper in Rails; apply Cache-Control: no-store for refusals unless a broader caching policy is approved.
- Release 4: Canary – enable the dual-v1 profile for a small cohort; collect observability metrics and confirm no regressions.
- Release 5: Expansion – roll out to remaining internal callers after stability; remove the flag once confidence is high; maintain a rollback path.

## 4. What not to do: hard-to-reverse migration mistakes

- Do not flip a reason’s meaning from 200 to 4xx and back without coordinated client contracts; version the HTTP profile or encode the mapping in the contract. 
- Do not let generic clients retry every 503/502/504; the CPCP seam is POST, and retries may cause duplicates for non-idempotent writes; status should describe transport outcome, not imply success of the operation.
- Do not use 401 for every authorization problem; 401 is for missing/invalid credentials; 403 is for domain-level denial when endpoint authorization has succeeded. The failure-layer distinction must be explicit in the contract.
- Do not use 400 as a catch-all for all errors; 422 is standard for semantic-invalid content; reserve 400 for syntactic/format errors. 
- Do not map all dependency failures to 502; 503 is for temporary unavailability, 504 for upstream timeouts, and 500 for server-internal issues. Use Retry-After only when appropriate and when a safe retry policy exists.
- Do not allow 404-based refusals to become cacheable; by default, refuse caching of refusal responses unless a caching policy proves it safe. POST responses are generally not cacheable unless explicit freshness metadata is present.
- Do not let monitoring regressions hide migration progress; maintain separate counts for HTTP status, envelope ok, failure_layer, reason, and retryability, and record a migration marker in analytics.

## 5. The CI gate

A comprehensive gate should assert several properties beyond merely that callers inspect non-2xx statuses:
- Completeness of the caller inventory for POST /_cpcp/rpc and approval of wrappers.
- Every Python path consumes 4xx/5xx bodies; planted tests should ensure HTTPError bodies are read and parsed.
- Every caller separates transport status from the envelope ok signal; tests should fail if a non-2xx maps to a surrogate 200 envelope without proper separation.
- Each refusal reason has an explicit status mapping and a failure layer; unmapped reasons trigger a defect.
- The mapping must be table-driven and stable; changes should trigger a review and regression tests.
- 401 responses include WWW-Authenticate headers; missing headers trigger a defect.
- Temporary 503s expose Retry-After; permanent 500s do not include misleading Retry-After.
- Non-idempotent writes are not retried solely on status; a safe replay contract must exist.
- Refusal responses are not cached by default unless a validated policy allows it.
- Rails controller has no remaining unconditional status render path for the seam; new code paths must use a single mapping engine.
- The body envelope remains conforming for all mapped refusals; any unmapped refusals risk loss of meaning in transit.

The planted defects must be detected by CI. A checker that passes without detecting a defect, or passes due to examining too small a portion of the codebase, should fail the CI job with a diagnostic that explains the deficiency.

## 6. Observability and rollback

Emit one structured event per request with correlation_id and at least the following fields: cpcp_http_profile, http_status, envelope.ok, reason, failure_layer, retryable, method, caller_identity, and an operation/commit identifier. For infrastructure failures, include the dependency and failure mode (unreachable, invalid_upstream_response, timeout, busy, not_installed, schema_check_failed). Avoid exposing secrets or authorization data in logs.

Track two parallel error-rate families: transport classification (4xx, 5xx, timeouts, connection failures) and application outcome (envelope ok true/false, further split by failure_layer and reason). Alerts should reflect both signal lines rather than substituting one for the other.

Rollback means disabling the dual-v1 profile and returning to the prior profile while preserving client fixes. Rollback criteria include a rise in duplicate writes, missing reason data, unsupported 401 header content, cache-control violations, or any caller that cannot parse a refusal body. Rollback thresholds are NOT ESTABLISHED by the supplied facts and should be set using baseline traffic and incident tolerance.

## 7. Recommended implementation shape

Represent the result as a typed object with fields such as envelope, http_status, failure_layer, and retryable. The Rails controller should map the typed outcome to a concrete HTTP status and headers, preserving the envelope values. This approach minimizes irreversible changes to the envelope and ensures a stable contract across updates.

The initial profile is:

- 200: completed RPC whose result is a domain outcome (grounding/admission refusals when classified as domain)
- 400: malformed HTTP/JSON/request syntax
- 401: missing or invalid caller authentication; include WWW-Authenticate
- 403: endpoint/resource authorization refusal
- 404: missing or undisclosed HTTP target
- 422: SHACL semantic rejection signalling (optional, CPCP policy depends on whether to expose semantic validation at HTTP level)
- 500: permanent/unexpected server/configuration failure
- 502: invalid upstream response at a gateway boundary
- 503: temporary unavailability or dependency failure
- 504: upstream timeout at a gateway boundary
- Retry-After: only for temporary conditions with meaningful delays
- Retry policy: not inferred from status alone; deduplicate or idempotency policy is required for safe replays
- Cache-Control: no-store by default unless a broader caching policy is approved

A single policy decision that must be finalized before code merge is whether SHACL grounding refusals remain 200 as domain outcomes or become 422 as HTTP-level semantic signals. Both choices can be defended under RFC 9110; the critical requirement is to document and enforce the chosen mapping consistently across all callers and methods.

## 6. Sources

- RFC 9110: HTTP Semantics — https://www.rfc-editor.org/rfc/rfc9110.html
- JSON-RPC 2.0 Specification — https://www.jsonrpc.org/specification


## 7. References

- RFC 9110: HTTP Semantics — https://www.rfc-editor.org/rfc/rfc9110.html
- JSON-RPC 2.0 Specification — https://www.jsonrpc.org/specification
