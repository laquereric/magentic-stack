# Gap analysis

Diagrams and per-container detail: [`ContainerTopology.md`](ContainerTopology.md).

Measured 2026-08-31 at `030af95`. Doctrine: ADR 0046 (vault separate), 0047 +
amendments (three languages, container boundaries, one Rails app many ROLEs),
0048 (MIND serves a CPCP seam), 0049 (ROLE=shape from mounted gems), 0050
(SwitchYard is the upstream; bus and persist are Rails ROLEs).

**Target: 12 containers, 4 images.** One Rails application under **nine** ROLEs,
plus MIND (Python), SwitchYard (NVIDIA Rust + a CPCP endpoint), and oxigraph.

Row numbers are stable across revisions so they can be cited; the DB_PATH block
(39-47) was inserted later and therefore sits out of sequence.

## 0. Rollup

| State | Rows | Meaning |
|---|---|---|
| **prerequisite** | 39, 43 | blocks other work; do these first |
| **owner decision** | 15, 18, 20, 41, 46, 48, 49, 68, 69, 72, 73, 82, 83, 84, 87, 91, 94 | needs your call, not more analysis |
| **next** | 5, 6, 50 | briefed or briefable now |
| delegated | 61 | with grok now |
| blocked | 9 (by 17), 10 (**by 14, which is closed -- row 10 is unblocked**), 11 (by 15, 18, 19) | waiting on another row |
| open | 7, 8, 12, 17, 19, 22, 40, 45, 59, 70, 75, 81, 85, 95, 96 | known, unscheduled |
| rework pending | 4 | built, needs redoing |
| decided, unbuilt | 86 | ruled; nothing built yet |
| reframed | 13, 23 | the row as written was the wrong question |
| carve-out or unowned | 25, 26, 27, 28, 29, 30 | section 3, outside the language rule |
| closed | 1, 2, 3, 14, 16, 21, 24, 42, 44, 47, 51, 52, 53, 54, 55, 56, 57, 58, 60, 62, 63, 66, 67, 71, 74, 76, 77, 78, 79, 80, 64, 65, 88, 89, 90, 93, 92 | 37 rows |
| no state by design | 31-38 | sections 4 and 5 are descriptive tables with no State column |

_Fully reconciled 2026-08-31 against the table as committed. Population: **96 rows**, of which 88 carry a State column and 8 (31-38) do not; every row appears in exactly one line above. State was read as the last cell, after confirming each section has a uniform field count, so no embedded pipe shifts which cell is read. The `## Critical path` table has its own numbering (1, 2, 2b, 3, 3b) and is excluded. The prior rollup listed nothing above row 47 and named three closed rows as needing an owner call._

## 1. Containers

| # | Container | Image | Today | Gap | State |
|---:|---|---|---|---|---|
| 1 | `back` | Rails | `ROLE=back`, a declared domain writer (ADR 0056), draws `/_cpcp` | ~~shares `mind-data` with `backjob`~~ **that is now the correct arrangement** — two declared writers | closed |
| 2 | `backjob` | Rails | `ROLE=backjob`, CPCP completion works | ~~`Reconciliation.create!` is a violation~~ **CLOSED by ADR 0056 as a DECLARATION, not a fix.** BACKJOB is a declared co-writer. New work moves to rows 76-79 | closed |
| 3 | `front` | Rails | `ROLE=front`, route-gated off `/_cpcp` | served the write seam until `0a7d67f`; historical overlay gone — see row 24 | done |
| 4 | `vault` | Rails | `ROLE=vault` landed `968d3cd`, bespoke REST | **inbound edge becomes a CPCP contract, TBD (0046 amendment 2)** — must land BEFORE `config-admin`, which is its first caller | rework pending |
| 5 | `config-admin` | Rails | does not exist | build as `ROLE=config`; the **only** published port; inherits catalogue/discovery/verify if they have no upstream home (row 15) | **next** |
| 6 | `shape` | Rails | design landed `16c35a1`. **Its `incomplete:true` reason was wrong**: not "52 remain", but that protocol P2–P8/P10 are not in the pin and `shapes-level-8` is not in `SHAPE_MAP` | build v1 per `ROLE_SHAPE.md`; fix the incompleteness reason | **next** |
| 7 | `project-graph` | Rails | **Mechanical half landed.** Storable IS wired (`project_on_save!`). Canonical `MM_OXIGRAPH_URL` was **two** env settings (back, backjob), not three — the third grep hit was the comment. Extract now sets the same two plus `VV_GRAPH_TRIPLE_GATE=strict`. SPARQL `{ok:false}` on emit is RefusalLog `graph_unreachable` with restoration, not `:applied`. Gate: `check_oxigraph_env.py` | live volume still **0 triples** until someone runs `graph.replay` (not this half). Whether projection stays in BACK or becomes `ROLE=project-graph` is an owner call | open |
| 8 | `persist` | Rails | does not exist | **SCOPED (0050 amendment).** Owns the write-LOCATION decision, not the data. Holds the closed path set of row 39 and enforces row 43 | open, scoped |
| 9 | `bus` | Rails | does not exist | **SCOPED (0050 amendment).** Implements RES: event log content, streams, append, pub/sub, CPCP interface. Does not decide where it is written | open, blocked by 17 |
| 10 | `mind` | Python | CPCP **client** only: `CMD ["harness.py"]`, no `EXPOSE`, no inbound surface | must serve `/_cpcp/rpc`, map NOOA push/pull | **blocked by 14** |
| 11 | `SwitchYard` | NVIDIA Rust + CPCP endpoint | **Node**: 17 `.mjs`, 350-line `server.mjs`, two ports one process | replace with the upstream proxy; add a CPCP endpoint | **blocked by 15, 18, 19** |
| 12 | `graph` | oxigraph, third-party | running, digest-pinned, **empty** | exemption from the language rule is assumed, not written | open |

## 2. Cross-cutting gaps

| # | Gap | Measured today | Blocks | State |
|---:|---|---|---|---|
| 13 | **CORRECTED.** The shapes ARE the language-neutral spec | `grounding.rb:123`: "The shapes are the specification and CI runs pyshacl over them with fixtures"; the Ruby is a deliberate hand-written reproduction because `mm-shacl-reader` is not wired in-process. `pyshacl` is already pinned | what is missing is **distribution**, not authorship -> row 6 | reframed |
| 14 | ~~Behavioural contract is Ruby-only~~ | **WRITTEN** at `55dbd82`: `ContainerTopology`'s companion `CPCP_BEHAVIOUR.md` — 324 lines, 63 `file:line` citations, **16 SPECIFIED vs 38 OBSERVED**, plus what could not be determined | — | closed |
| 15 | **SwitchYard parity: catalogue, discovery, verification** | `catalog.mjs`, `discovery.mjs`, `verify.mjs` have **no described upstream equivalent** | replacing the Node service | **owner decision** |
| 16 | ~~Bus vs persist~~ | **CLOSED.** BUS implements RES; PERSIST determines the filesystem write location for the Event Store. Departs from memo 0830d deliberately — that memo reasoned about a Rust router holding credentials; the premise moved | — | closed |
| 17 | **`rails_event_store` is a new dependency** | **zero hits** in the repo; adoption, not relocation | row 9 | open |
| 18 | **The CPCP endpoint's language, and do-not-fork** | ADR 0038 + the `adapters-sole-path-to-upstreams` gate forbid patching upstream; `gems/adapters/` contains **one file, a README** | row 11 | **owner decision** |
| 19 | **Upstream is pre-alpha by its own README** | "experimental… not for production use"; API expected to change before v1.0 | row 11 | **accepted risk?** |
| 20 | **FIVE CPCP seams; authority stated for one** | BACK, MIND, SwitchYard, `bus`, and now `vault`. Every "the seam is the only write path" sentence predates the second | reading the invariant literally | **owner decision** |
| 21 | ~~Route-gating not CI-gated~~ | **CLOSED.** `check_role_routes.py` boots each ROLE and diffs the DRAWN table against `role_routes.json`; roles discovered both-ways from `entrypoint.sh` + both composes. 4 boots, ~5s | — | closed, see 51 |
| 22 | `osi.example` is unresolvable | 11 shapes resolve under `https://osi.example/shapes/...` | becomes externally visible when `shape` SERVES | open |
| 23 | ~~Shape payload part-migrated — "7 of 59"~~ | **THE FRACTION WAS WRONG AND I REPEATED IT.** 7/59 compares a runtime pin to a mixed tree. The 52 is: **26 pyshacl example fixtures (not shapes at all)**, 4 ontology, 2 allowlist templates, 20 under `shapes/` of which 5 are byte-identical P1/P2 copies — **unique shape contents ≈ 15, not 52**. And step 10 is RETIRE after soak, not move. There is almost nothing to MOVE | no useful single number exists; retirement, not migration | reframed |
| 24 | ~~FRONT historical exposure~~ | **CLOSED.** Reachable until `0a7d67f` (extract compose published FRONT `:13000`, routes mounted `/_cpcp` for every ROLE, image baked a writable sqlite). FRONT overlay `/rails/db/mind_pod.sqlite3` is gone with the containers. Image sqlite is the Aug 19 host snapshot, not a FRONT overlay. Volume `mind-pod-demo_mind-data` is BACK. Findings: [`GAP24_FRONT_CPCP.md`](GAP24_FRONT_CPCP.md) | — | closed |
| 49 | **Vault refusals vs the never-raise envelope** | vault answers HTTP 401/403; CPCP answers `{ok:false, reason:, because:}` with 200. A credential broker that returns 200 to a refused read is harder to monitor and easier to mishandle | vault's CPCP contract | **owner decision** |
| 50 | **Contract-before-caller sequencing** | `config-admin` is next on the critical path and is vault's first caller; built today it targets REST, built later it targets CPCP | building `config-admin` twice | **next** |
| 51 | ~~Route gate excludes `/rails*` by path string~~ | **CLOSED** at `02e59a2`, and closed harder than briefed: the path-prefix skip is GONE, not made provenance-based, and any `skipped` entry is now itself a FAIL. My plant `GET /rails/backdoor` on `vault` -> `vault extra GET /rails/backdoor`, exit 1 | — | closed |
| 52 | ~~A P6 denial is stored as `admitted`~~ | **CLOSED** at `6803c72`. Column dropped; admission derived from the journal in three states + an `indeterminate` alarm. Verified in SQL on the real host DB: `cid:sha256:cb841fdf` journals `received,grounded,refused` while the column said `admitted` — column predicate selected 4, journal derivation selects 3 | — | closed |
| 53 | ~~Two replay body shapes for one write~~ | **CLOSED** at `53f98e2`. One replay document for any PUSH replay, compact (absent cids omitted); first success stays domain-shaped. Caller analysis covered all nine; none break | — | closed |
| 54 | ~~Invalid JSON becomes `unknown_operation`~~ | **CLOSED.** `empty_body` and `unparseable_json` are now distinct refusals, specified as != `unknown_operation` | — | closed |
| 55 | ~~Dispatcher retry reports `replayed:false`~~ | **CLOSED** with 53 — same defect, the frozen first response | — | closed |
| 56 | ~~`l8.execution.complete` rows have an empty journal~~ | **CLOSED** at `f1dab59` (ADR 0053). Complete rows journal themselves — `received` at creation, `completed` after the receipt. Additive: parent journals verified unchanged (7 entries before and after). Still `not_an_admission`; `NOT_AN_ADMISSION_NAMES` untouched; indeterminate still 0 | — | closed |
| 57 | ~~2 historical rows unclassifiable~~ | **CLOSED.** Backfilled `authorized` entries carrying `backfill:true`, `not_a_p6_permit:true`, the reason, ADR 0052 and a timestamp — a reader can always tell P6 never saw them | — | closed |
| 58 | ~~`indeterminate` must stay empty~~ | **CLOSED.** `check_admission_indeterminate.py` gates it; the migration itself refuses to drop the column when the count is non-zero, and writes the gate artifact BEFORE aborting | — | closed |
| 59 | **The CPCP seam already has Python and JS callers** | `rails-cpcp/front/app.py`, `mind/harness.py`, and `switchyard-offline` (which SERVES its own `/_cpcp`). Nine callers across three languages | ADR 0048 treated a non-Ruby implementation as a FUTURE risk; it is present tense. Envelope changes must carry a caller analysis | open, informational |
| 60 | ~~The app image bakes local dev databases~~ | **CLOSED.** `app/.dockerignore` excludes `db/*.sqlite3` and WAL/SHM. `check_no_baked_sqlite.py` gates the file and, when `MIND_POD_IMAGE` is set, `find`s the image. FRONT boots `/up` and `/` with no sqlite in the image (vault-test probe and post-dockerignore rebuild); `/governance` 500 in the probe was a view `nil[]` with BACK down, not AR. Did **not** add `db:prepare` to FRONT | — | closed |
| 61 | **`make demo` cannot run, and the docs teach a 404** | **MY ROW MISSED THE ENTRY POINT.** `Makefile:32` invokes `-f test/docker-compose.demo.yml`, which **does not exist** (test/ holds only `docker-compose.ci.yml` and `docker-compose.session.yml`), so the compose call fails outright. Even if it ran, canonical compose publishes exactly one port -- `13001:8790` (switch) -- so `Makefile:33` waits 60x2s on `:13000/up` that nobody serves, then `Makefile:34` runs the boundary test against it. The original row also holds: in `extract/compose.yml` it is **FRONT** that publishes `13000:3000` (line 46), BACK is unpublished, and FRONT is route-gated off `/_cpcp` -- so `QUICKSTART.md:117,139,142`, `.threedot/cid.json` backUrl, `README.md:56`, `extract/compose.yml:4` and `bootstrap:51` all teach a call that 404s. Keep the distinction: `:13000` as the FRONT **web page** is correct (QUICKSTART:115, 167); `:13000` as a **CPCP endpoint** is not | the documented entry point is broken before the gated-path problem even applies | delegated to grok |
| 62 | ~~MIND system prompt false about the graph~~ | **CLOSED** at `b1f871b`. Established from source that the CLASS docstring IS the system prompt (`agent.py:437`) and the METHOD docstring the task prompt (`prompts.py:64`); the module docstring is human-facing and was audited anyway. FALSE claims removed, not promised: SPARQL as MIND's surface, RDF knowledge today, named-graph layout, sole-writer singular, "bounded SELECT" | — | closed |
| 63 | ~~Never-raise has no observer~~ (ADR 0054) | **STEP 2.** One collector (`RefusalLog` JSONL + heartbeat), not 29 edits. Dispatcher observes `Envelope.fail` and nested `{ok:false}`. No-context sites (publisher, backjob, blob open, idempotency, FRONT) call `record` without changing their return values. Gate: `check_refusal_observer.py`. Findings: [`GAP63_STEP2.md`](GAP63_STEP2.md) | 8 UNCLEAR remain (64, 65) | closed as collector; UNCLEAR not in scope |
| 68 | **5 of the 8 UNCLEAR need a CONTRACT change, not observation** | Manus `2026-08-31a`: **U2, U3, U5, U6, U7** — a side-channel cannot make the caller act differently. **U1, U4, U8** are observation-only *provisionally*, pending what our callers actually do with the value (not established for U1/U4) | — | **owner decision** |
| 69 | **U6 is highest urgency: projection proceeds WITHOUT durability** | `ensure_schema!` returns `false` for both "outbox not installed" and "schema check failed", and projection continues either way. Manus: observation cannot prevent it; the contract must change and the policy (stop / retry / named degraded path) is **not established** | plausibly a second reason GRAPH is empty (gap 7) | **owner decision** |
| 70 | **No sentinel, no out-parameter, no Dry::Monads** | Manus rejects sentinels (missed by truthiness, equality, serialization, cross-language clients) and out-parameters (non-idiomatic, aliasing, does not solve durable observation). Recommends an OWNED plain-data envelope — hashes/booleans/strings/numbers/arrays/null only — so Python, JS and Rust can consume it | shape for the 29 and the 8 alike | open |
| 71 | ~~Two integrity authorities~~ | **CLOSED.** BACK and BACKJOB write domain state (ADR 0056); BUS is the source of truth for METADATA (ADR 0057). Neither is "integrity" in the abstract. RES records successes AND failures; BACK and MIND HANDLE them — recording and handling are different jobs with different owners | — | closed |
| 72 | **Does BUS become a runtime dependency of every call?** | if BUS holds the state between the two RPC halves it sits in the path of every call, not an async side-channel. Today `/_cpcp/rpc` is a synchronous POST BACK completes alone | can any call complete while BUS is down? Materially changes the availability story | **owner decision** |
| 73 | **What state actually moves to BUS** | the two halves of an L8 call are admission and `l8.execution.complete`; the state between them is the `OperationRequest` row plus journal in BACK's SQLite -- exactly what ADRs 0052 and 0053 corrected today | if it moves, those ADRs describe the right invariants in the wrong place. **My reading; confirm before building** | **owner decision** |
| 74 | ~~Envelope refusals are not restoration-grade~~ | **CLOSED.** ONE new attribute key, `cpcp.restoration` = state_reached / inconsistency / restore_when / restore_action, from roughly sixteen proposed fields. Six mapped to OTEL-native, three omitted rather than fabricated, two dropped. All-or-nothing: any blank key drops the whole object, verified 7/7 independently | RestorationShape excluded from the OSI L8 census with a stated reason; 171 in-scope, 5 exclusions | closed |
| 75 | **BUS changes must force participant rebuilds** | ADR 0055 clause 4. **Owners named: BACK and MIND** handle build-time alignment. Crosses images and languages — MIND is Python, SwitchYard Rust | we have cid identity, SHACL as the neutral contract, and fail-closed gates; missing is which BUS changes are BREAKING, and a gate refusing a participant pinned to a superseded contract | open, owned |
| 76 | ~~"Sole writers" does not say who writes what~~ | **CLOSED** at `db1de82`. `config/domain_writers.json` states it; `DomainWriters` gates it on `before_save`/`before_destroy` **plus** `sql.active_record`, because `insert_all` bypasses callbacks. `unknown_role: refuse` | — | closed |
| 77 | ~~WAL inherited, not declared~~ | **CLOSED.** `database.yml` now declares `pragmas.journal_mode: wal`. Measured before and after: already `wal` from Rails 8 `DEFAULT_PRAGMAS`, so the runtime is unchanged and the **guarantee** is what was delivered | — | closed |
| 78 | ~~SQLITE_BUSY would be invisible~~ | **CLOSED.** A real `BEGIN IMMEDIATE` collision recorded as `reason=sqlite_busy` in `RefusalLog` — its first real customer. Instrumentation, not a contract change: BACKJOB's loop has no caller | — | closed |
| 79 | ~~"BACK is the sole writer" false everywhere~~ | **CLOSED for LIVE PROSE.** routes.rb, both compose headers, READMEs, QUICKSTART, bootstrap, rails_cpcp.rb, engine.rb, translation_board.rb. ADRs deliberately untouched — a dated record gets an amendment, not an edit. The CPCP "sole writer on the far side" text is still TRUE: the seam far-side is BACK | — | closed |
| 80 | ~~"Durable memory" misclassifies MIND's store~~ | **CLOSED.** The prompt now says inference memory that is "nondeterministic inference state, not application state and not metadata" — the three-way division taught explicitly. "Durable" now attaches only to what BACK commits: *committing it makes it durable rather than true* | — | closed |
| 81 | **A fourth audit verdict: MISCLASSIFIED** | roughly true, but names the wrong KIND of thing and so teaches a wrong division | a statement that is factually accurate and categorically wrong is WORSE than one plainly false, because nothing will contradict it | open |
| 82 | **Should MIND's state survive a restart?** | mind-nooa-data is a NAMED volume: survives restart, dies on down -v. If the state is ephemeral that may be the volume, not the word, that is wrong | the original reasoning (not a credential, down -v should clear it, NOOA's virtiofs warning) is intact; what was never asked is whether it should survive a RESTART | **owner decision** |
| 83 | **Cache identity is unknowable from where MIND sits** | MIND names no model; SwitchYard routes across providers. Manus: persistent KV restoration is UNSAFE unless execution identity is pinned or attested. Model weights, tokenizer, chat template, sampling config, adapter, cache format -- **every one marked "not established" for us** | three safe options: SwitchYard exports a verifiable execution identity, the router owns reuse, or durable reuse stays off. **Do not use MIND's model opacity as a reason to guess** | **owner decision** |
| 84 | **There is no general stale-block detector** | Manus, answering directly: no established detector distinguishes a semantically stale but structurally valid block after the fact. SHACL validity, checksums, successful deserialization and fluent output all pass | **the control must be PREVENTION, not detection.** A cache hit is a risk-bearing admission, not proof of correctness. Breaks any expectation that our SHACL gates catch plausible-but-incorrect inference | **owner decision** |
| 85 | **A KV cache is not a participant, but needs participant-like gates** | it cannot recompile -- it is derived output. The BUS-imposes-change rule should bind the CONSUMER and a cache-admission contract, not the artifact | needs an explicit concept of ARTIFACT COMPATIBILITY: a superseded artifact may remain on disk for diagnostics but must not be consumed | open |
| 86 | **LOG: OTLP transports, CPCP governs** | Manus 2026-08-31d, given permission to reject CPCP as transport and taking it. Ordinary log volume must NOT go through the per-record admitted-operation path; CPCP supplies method/schema identity, admission policy, refusal semantics, receipt rules | five stages, local append BEFORE any network | **decided, unbuilt** |
| 87 | **LOG does not close ADR 0054** | "shared lineage disqualifies LOG as the sole final observation point, but does not disqualify LOG as an aggregation path". Its permitted claim is weaker: LOG helps WHEN THE SHARED LINEAGE IS HEALTHY; it cannot evidence that the lineage failed | something outside the Rails image is still required for high-value failure evidence | **owner decision** |
| 88 | ~~We are inventing an OTEL-to-SHACL vocabulary~~ | **DOES NOT ARISE.** Ruled: do not reformat OTEL; SHACL only for required NEW metadata; prefer none. An OTEL LogRecord stays native and untranslated, so there is no translation layer to author or own | new metadata means a new attribute KEY, not a new format -- SHACL constrains values of keys we define | closed |
| 89 | ~~The failure-domain test is not premature~~ | **CLOSED as a measurement, not a fix.** Restart, chmod, first-write: both invariants hold. Directory gone: both fail (the floor is the file; recreate looks like a healthy short log). SIGKILL: no torn line observed (write finished first). Disk full: APFS RAM disk still had ~1MiB after ENOSPC on a neighbor file — not a zero-byte disk; JSONL still wrote. Findings: [`GAP89_FLOOR.md`](GAP89_FLOOR.md) | — | closed as measured |
| 64 | ~~A fallback defeats its own check~~ | **CLOSED.** Parse errors are `:unparsable_frontmatter` (now reachable). Empty YAML is no-fields, not corrupt. Non-Hash is `:frontmatter_not_a_mapping`. Ingest is the only runtime reader of the symbol. Findings: [`GAP64_65.md`](GAP64_65.md) | — | closed |
| 65 | ~~A failed idempotency store looks like a success~~ | **CLOSED without mounting sqlite.** Live store is MemoryIdempotency. Once-per-process `idempotency_not_durable` on RefusalLog. `get` stays nil-on-failure. Sqlite still not mounted; mounting list is in [`GAP64_65.md`](GAP64_65.md) for persist (39/43) | — | closed |
| 66 | ~~shapes-level-8 packaged but unreachable~~ | **CLOSED. The CATALOG was wrong, not the manifest.** The manifest already named 13 P11 protocol NodeShapes runtime with source_shape in shapes-level-8, while ProfileCatalog defined L8 and never used it, against its own comment: Ownership from the binding manifest, do not re-decide here | now resolves them; gated by check_catalog_manifest.py | closed |
| 67 | **MY ROW WAS WRONG, NOT comments only** | P9 canonical vs L8 bundle also differ in sh:ignoredProperties: legacy carries rdf:type PLUS six governed fields, packaged carries rdf:type ALONE. Under sh:closed true the packaged shape is strictly STRICTER. I recorded same-enforceable-constraints and repeated it | **the fix I warned against would have HIDDEN this** -- a comment-insensitive hasher converges the two and buries a real closed-shape delta. Recorded in packaged_vs_legacy.json; gate NOT weakened | closed |
| 90 | ~~A consumer resolves from a gem it does not declare~~ | **CLOSED.** `rails-osi-level-8.gemspec` now declares `shapes-level-8` directly. `resolve` allowlists `SHAPE_GEMS` and refuses any other name; repo_root fallback is only for that list, and is not a declaration. Gate: `check_shape_consumer_deps.py` (2 consumers examined). Plant: undeclared consumer fails; empty CHECK_ROOT fails | — | closed |
| 91 | **The protocol engine depends on the application contracts** | `rails-osi-level-8` -> `shapes-application` -> `shapes-level-8`. The inner link obeys the rule application -> protocol, never reversed; the outer one means the engine named for the protocol hard-depends on THIS application -- **74 of the catalog 87 entries** resolve into `contracts/mind-pod` (16 SHAPE_MAP keys plus the P9 and P11 operation generators), against only 13 from `shapes-level-8`. A second application would inherit the mind-pod shapes, the scenario step 1 required to be represented. Counter-argument is real: the engine is the Rails BINDING, not the protocol definition, and a binding may legitimately depend on both | whether the ownership rule governs consumers or only the two shape gems | **owner decision** |
| 92 | ~~The ADR corpus does not validate against its own ingest~~ | **CLOSED.** Extended `SUBJECT_KINDS` with topology/doctrine/data (same reason `repo` exists — do not mislabel). Did not reclassify. `:constraint` means empty `enforced_by`; filled it on the in-force ADRs that named none, did not weaken `expect(breaks).to be_empty`. Gate: `adr-ingest.yml` runs the full mmg-adr suite. Findings: [`GAP92.md`](GAP92.md) | — | closed |
| 93 | ~~Only one failure reason fails closed; four others still report applied~~ | **CLOSED.** `failed_envelope?` is any `{ok:false}`. The engine-limited SPARQL-star annotation DELETE is `rdf_star_annotation_delete` (a call site), not a reason allowlist. Immediate observes every SPARQL reason with restoration and does not mark applied. Gate: `check_projection_envelope.py` | — | closed |
| 94 | **The outbox already says applied for projections that never landed** | gap 7(b) is forward-only. Measured live: 96 notes, 0 triples -- so existing outbox rows are marked `:applied` for work GRAPH never received, and being applied they will never retry. The fix stops NEW mis-marking; it does not unwind the state already recorded | needs the replay call (row 7 owner half); do not backfill unasked | **owner decision** |
| 95 | **The call-site exemption still returns ok on a retract-only quoted-triple path** | gap 93 narrowed the exemption correctly, but `sparql_delete` returns a bare `{ok:true}` when `subject_term` starts with `<<`, and `retract_predicate_via_update!` (storable.rb:784) returns THAT with no following non-star write. `replace_predicate!` has the same shape when `insert_clause` is empty -- early `{ok:true, count:0}`. grok stated GRAPH-down is caught by the next non-star execute; that holds on the emit paths, NOT on a retract-only path. **LATENT, not live:** `subject_term` at all three `retract_predicate!` callers (494, 520, 658) is a primary subject, never a quoted term, so I could not construct a live path. Record so a future caller passing a quoted term does not resurrect gap 7(b) | a retract of an annotation could report success against an unreachable GRAPH | open |
| 96 | **`enforced_by` is asserted non-empty, never resolved and never verified to enforce** | gap 92 made `ingest_spec` green by POPULATING `enforced_by` -- correct, and I verified no reference was invented: **102 refs across the corpus, 0 missing on disk.** But that was a one-off manual check. `:constraint` means the list is EMPTY, so the spec asserts presence only; `check_adr_kinds.py` does not read `enforced_by` at all. Nothing asserts the path still exists (a rename silently re-breaks it), and nothing asserts the named file actually enforces the decision. grok states plainly that unbuilt targets name a **live stand-in** -- so by design some entries point at something adjacent to the enforcement, not the enforcement | a decision can read as enforced because a real file is named next to it | open |

## 2b. DB_PATH as a CPCP effect (ADR 0051)

| # | Gap | Measured today | Blocks | State |
|---:|---|---|---|---|
| 39 | **The path parameter must be a CLOSED set** | none exists; `DB_PATH` is a free-form env string read once by ERB. **`persist` now holds this set** (0050 amendment) | ADR 0051 | **prerequisite**, owner = `persist` |
| 40 | **Boot-time resolution; a change is a reconnect** | `database.yml` evaluates `ENV.fetch("DB_PATH")` in ERB at load; consumers also in `entrypoint.sh` (x2) and `spec_helper.rb` | quiesce/swap/resume semantics and in-flight request behaviour are undefined | open |
| 41 | **The bootstrap paradox** | CPCP records operations in the database being changed | the audit chain at the moment of the swap; needs the receipt in BOTH stores under one `operationId` | **owner decision** |
| 42 | ~~MIND has a SQLite it does not bind~~ | **DONE.** `DB_PATH` binds `SQLiteStorageManager`; unset keeps NOOA's `:memory:` default. Named volume `mind-nooa-data` in both composes | — | closed |
| 43 | Row 1 becomes reachable at runtime | two writers on one file needs a compose edit today | **`persist` enforces this** as its invariant, rather than every caller | **prerequisite**, owner = `persist` |
| 44 | ~~Does `ROLE=persist` survive?~~ | **CLOSED. Yes.** Placement authority is a job it can do without a database server — which is what "persist owns physical storage" foundered on | — | closed |
| 45 | **NOOA already enforces single-writer** | `_acquire_session_lock` + `SessionAlreadyActiveError` | gap 43 should ADOPT this mechanism, not grow a parallel one | open |
| 46 | **A path is a file triple, on a hazardous mount** | WAL mode adds `-wal`/`-shm`; `delete_sqlite_database` unlinks all three. NOOA ships `_is_virtiofs` because SQLite misbehaves on Docker Desktop sharing, and ADR 0046 requires a **bind mount** for `down -v` survival | the closed set (39) enumerates triples; mount type is a decision | **owner decision** |
| 47 | ~~MIND's system prompt becomes false~~ | **DONE.** Prompt rewritten and the store bound in the same change: "you never persist anything" -> a WHAT YOUR OWN MEMORY IS, AND IS NOT section; memory is private and is not evidence | — | closed |
| 48 | **Is `persist` the placement authority for EVERY store, or only the event log?** | the decision names the Event Store; ADR 0051 makes `DB_PATH` an effect for every Rails container and MIND (domain SQLite, NOOA memory) | scope of `persist`; the closed set in row 39 | **owner decision** |

## 3. Outside the language rule

| # | What | Count | Status |
|---:|---|---:|---|
| 25 | Python release gates under `tooling/` | 23 | **carve-out adopted**: "`tooling/` is Python until rewritten" |
| 26 | Python validators in `gems/osi-level-8-profiles` | 4 | same carve-out |
| 27 | Shell: `bootstrap`, `build-baselines`, `docker-containers`, `prereq` | 4 | outside all three languages |
| 28 | CI workflows (YAML) | 11 | not covered; they **invoke** the Python gates |
| 29 | `runtimes/effect-plane` | 1 gem | no container assigned |
| 30 | `mmg-blob` / `vv-blob` | 2 gems | blob storage has no owner |

## 4. Browser carve-out (not violations)

| # | What | Why JS |
|---:|---|---|
| 31 | `gems/switchyard-offline` | Chrome MV3 extension; the one gem with **no gemspec** |
| 32 | `gems/vv-html-components` | web components |
| 33 | `rails-osi-level-8/.../ux-host-layout.js` | browser asset |
| 34 | `config-admin`'s UI, once it exists | runs in a browser |

## 5. Accepted costs and dead prose

| # | Item | Source |
|---:|---|---|
| 35 | Hot-patch granularity is 4 units, not 12 | 0047 amendment 1 |
| 36 | ADR 0046 keeps its network/mount/allowlist boundary but loses image isolation | 0047 amendment 1 |
| 37 | `mind_agent.py:58` "There is no second socket, and there is no write path for you" — now false | 0048 |
| 38 | Every "`/_cpcp` is the ONLY write path" comment — now false; means *BACK is the only writer of domain state* | 0050 |

## Critical path

| Order | Do | Why |
|---:|---|---|
| 1 | **Row 21** — route-gate checker | five new ROLEs are coming; the invariant must be enforced before they land, not after |
| 2 | **Row 4/50** — define vault's CPCP contract | `config-admin` is its first caller; defining after building means writing the caller twice |
| 2b | **Row 5** — `config-admin` | gives `vault` its first caller and closes the credential-entry path |
| 3 | **Row 6** — build `ROLE=shape` v1 per [`ROLE_SHAPE.md`](ROLE_SHAPE.md) | design is in; the shapes ARE the spec; serving them is how MIND and SwitchYard conform (row 13) |
| 3b | **Row 14** — write down the behavioural half | payload validation is free; envelope, idempotency and the method registry are not |
| 4 | **Rows 16, 18** — bus/persist ownership, and the endpoint's language | both owner decisions; each blocks a new container |
| 5 | **Row 2** — the backjob writer boundary | still the only **live** correctness defect on this list |
