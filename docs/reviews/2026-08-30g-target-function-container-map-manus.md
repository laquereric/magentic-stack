<!--
Source: Manus cloud agent, task YGMMRxvkc3Y9gtjF9zC7y7
Commissioned 2026-08-30 by SuperDevAi on operator instruction.
Manus had NO repository access. Every fact it reasons from was supplied in the
brief (.mm_tmp/manus/container-map.prompt.md in the substrate repo), which was
verified against the tree at 735f724 before sending. Claims Manus could not
derive are marked "not established" throughout -- that is deliberate.

STATUS: exploration. Nothing here is authorized or built. The pod
re-partition remains an open owner decision; no registry is adopted.
-->

# Target Function → Production Container Map

## Scope and evidence rule

This mapping is based only on the supplied system brief. The brief is treated as the sole factual source. Any item that cannot be derived from it is marked **not established**. “Target” means the recommended ownership boundary, not an assertion that the topology has already been built or authorized.

## Decision summary

| Decision | Target answer | Status / boundary consequence |
|---|---|---|
| Application/domain authority | `back` remains the application-level writer for Rails/CPCP domain models | Preserve the semantic single-writer rule; remove `backjob`’s direct SQLite write. |
| Physical durable event repository | `persist` container | New boundary. `persist` owns the event repository and its storage; `switch-bus` does not. |
| LLM routing and provider calls | `switch-bus` container, implemented from the current Node `switch` lineage | Keep the Node implementation distinct from NVIDIA’s Rust upstream. |
| Human configuration and credential-entry surface | `config-admin` container | Split from the LLM data plane and expose only this surface to the host. |
| Provider credential brokering | `vault` container | New, narrow broker; no domain state, event participation, shared writable volume, or secret values in logs/events. |
| Agent client | `mind` container | Retain as a separate resource, failure, and credential boundary. |
| Browser-facing DB-less page | `front` container | Retain; it calls `back`. |
| RDF projection and Oxigraph serving | `graph-projector` plus `graph-store` containers | Separate projection work from graph storage/serving. Today’s `graph` combines only the store role and is empty because projection is unwired. |
| Reconciliation worker | `backjob` container without `mind-data` mount | It invokes the CPCP seam; `back` performs the domain write. |
| Effects, blob storage, shape validation, provenance/attestation | See Q1/Q2 rows below | Several are implied by repository trees but have no current container; some target owners remain **not established**. |

## Q1 — Function inventory: what performs each function today

| # | Distinct function | Evidence in brief | Performs it today | Current container / location | Current boundary observation |
|---:|---|---|---|---|---|
| 1 | Serve the browser-facing application page | `front` is a DB-less browser page and exposes port 3000 | Yes | `front` | Separate presentation process; it does not own domain state. |
| 2 | Call the application backend from the browser page | `front` has `BACK_URL=http://back:3000` | Yes | `front` | Network dependency only; no database sharing stated. |
| 3 | Serve the Rails application | `back` is a Rails 8 app | Yes | `back` | Application trust boundary and CPCP seam. |
| 4 | Mount and serve the Rails CPCP engine | `back` mounts the rails-CPCP engine; seam is `/_cpcp/rpc` | Yes | `back` | The seam is the application command boundary. |
| 5 | Authoritatively write L8/domain models by doctrine | `back` is the sole writer by doctrine | Yes, semantically | `back` | Not an enforced physical single-writer boundary today because `backjob` shares the SQLite volume. |
| 6 | Physically write the Rails SQLite database | SQLite is `/data/mind_pod.sqlite3` on `mind-data` | Yes | `back` and `backjob` can physically reach it | Shared writable volume defeats physical isolation. |
| 7 | Run reconciliation work | `backjob` is a separate role using the same image | Yes | `backjob` | Worker lifecycle/failure boundary exists, but storage isolation does not. |
| 8 | Directly create `Reconciliation` rows | `bin/backjob` performs `Reconciliation.create!` | Yes | `backjob` | This is an exception to the semantic sole-writer rule and should be removed. |
| 9 | Route L8 completion through CPCP | Brief says `backjob` routes completion through the CPCP seam | Intended code path exists | `backjob` → `back` | **Currently dead** because `BACK_URL` is absent and the default is loopback; rescued never-raise errors are only printed. |
| 10 | Provide the LLM data plane health endpoints | `8789` serves `/health` and `/v1/health` | Yes | `switch` | Pod-internal only; not host-published. |
| 11 | Accept chat-completions requests | `POST /v1/chat/completions` on port 8789 | Yes | `switch` | LLM-plane function. |
| 12 | Accept messages requests | `POST /v1/messages` on port 8789 | Yes | `switch` | LLM-plane function. |
| 13 | Discover/configure provider sources | Modules and APIs include `sources`, discovery, catalog, and `/api/sources` | Yes | `switch` | Currently co-resident with credentials, UI, and data plane. Exact provider semantics are not established. |
| 14 | Human-enter provider credentials | Keys are placed by the human through the 8790 UI | Yes | `switch` port 8790 UI | Human-entry path is coupled to the Node data-plane process. |
| 15 | Persist provider credentials across `docker compose down -v` | `/state` is a bind mount of `.agent/secrets`, not a named volume | Yes | `switch` bind mount | Credential durability is operator-managed; no Vault exists today. |
| 16 | Administer/test configured providers and tools | 8790 exposes `/api/refresh`, `/api/verify-tools`, `/api/test` | Yes | `switch` | Administrative control is co-resident with the data plane. |
| 17 | Route requests to providers and translate protocols | Modules include `providers.mjs`, `router.mjs`, `translate.mjs`; provider keys are in `switch` | Yes | `switch` | Exact routing and translation behavior beyond module names is not established. |
| 18 | Hold provider keys for runtime use | Brief says `SWITCH` holds every provider key and `MIND` holds none | Yes | `switch` | This is both credential storage and runtime secret access. |
| 19 | Run the agent client | `mind` is the agent client | Yes | `mind` | Separate image and process; no credential or model name is held there. |
| 20 | Call the backend and LLM plane from the agent | `mind` has `BACK_URL` and `SWITCH_URL` | Yes / configured | `mind` | Exact call flows are not established. |
| 21 | Serve an RDF graph store | `graph` runs Oxigraph on port 7878 | Yes | `graph` | Storage/serving role only. |
| 22 | Store RDF graph data | `graph-data:/data` is mounted | Yes, as a store capability | `graph` | The store starts empty because the projection is not wired. |
| 23 | Project Rails models into RDF | `graph` is described as a projection, but Storable projection is not wired | No | No container | Topology exists; contents do not. |
| 24 | Own authoritative domain state | Brief says graph is not authority; Rails models are authority by doctrine | Yes | `back`’s Rails/SQLite path | Physical ownership is not cleanly isolated from `backjob`. |
| 25 | Durable event-sourced repository / Rails Event Store | RES appears nowhere in this repo; it is doctrine in a separate substrate repo | No | No container in this pod | Any implementation in this pod is a proposal, not existing code. |
| 26 | Event bus / pub-sub transport | A bus/repository split was recommended, but no such implementation is stated as built | No | No dedicated container | Do not label current `switch` as an event store. |
| 27 | Credential broker / Vault | Brief explicitly says the Vault does not exist | No | None | Current substitute is `switch`’s `/state` plus UI entry. |
| 28 | Effect execution | `runtimes/effect-plane` exists outside today’s containers | No | No container | Function is implied by the tree; actual interface, workload, and authority are not established. |
| 29 | Blob storage | `mmg-blob` and `vv-blob` trees exist | No | No container | A production blob backend and ownership are not established. |
| 30 | Shape validation | Shape-related gems/trees exist: `shapes-application`, `shapes-level-8` | No | No container established | Whether validation runs in `back`, a gateway, or a worker is not established. |
| 31 | Semantic editing | `mmg-semantic-editor` exists | No | No container established | Runtime placement is not established. |
| 32 | Graph adapters/integration | `mmg-graph`, `vv-graph`, and `runtimes/graph` exist | No | `graph` is only the current Oxigraph store | Adapter and projection execution are not wired according to the brief. |
| 33 | ADR handling | `mmg-adr` exists | No | No container established | It is a repository function, not evidence of a running service. |
| 34 | Provenance/attestation attachment | Memo adopted OCI 1.1 subjects/artifactType and Referrers API as the right substrate | No | No registry adopted; no container | Function is a target governance/release capability, not a current pod function. |
| 35 | Run NVIDIA’s upstream Switchyard | `upstreams/nemo-switchyard` is Rust, submodule, and not running | No | No container | Strict do-not-fork boundary; do not conflate it with Node `switch`. |
| 36 | Build/deploy artifacts from repository trees | Monorepo and runtimes are described, but a production release service is not stated | Not established | Not established | Registry and deployment ownership are not established. |

## Q2 — Target function → production container map

The target names below are deliberate names, not claims that these containers already exist. A row marked **new** requires a topology change. Boundary justification uses the five requested tests: **trust, failure, resource, lifecycle, and deployment**.

| # | Target function | Target production container | Today | Boundary justification | Required invariant / explicit non-inference |
|---:|---|---|---|---|---|
| 1 | Browser-facing DB-less page | `front` | `front` | Presentation trust is distinct from domain state; browser-serving failures should not take down Rails, the agent, or LLM routing; resource profile is light; lifecycle and deployment are independently replaceable. | Keep DB-less. Additional frontend functions are not established. |
| 2 | Rails application, CPCP RPC seam, domain commands, and application-level domain writes | `back` | `back` | These functions share the Rails process, application trust model, request lifecycle, and deployment unit. Splitting them would create an unestablished RPC boundary without evidence of an independent resource or failure need. | `back` remains the only application-level writer. This does not by itself establish physical storage ownership. |
| 3 | Physical authoritative Rails/domain durable storage | `persist` or a separately identified domain-storage owner | Shared `mind-data` reachable by `back` and `backjob` | Physical write ownership requires an independent storage boundary. The brief and prior decision require PERSIST to own physical storage, but do not establish the protocol by which Rails would access it. | **Target owner: `persist` is recommended for the physical persistence plane.** The migration/API contract is not established; do not claim it already exists. |
| 4 | Reconciliation scheduling and work execution | `backjob` | `backjob` | Worker failure and scaling should be isolated from request serving; it has a distinct lifecycle and resource profile. It remains in the Rails image only because the brief says it uses the same image, not because it should share storage. | Remove `mind-data` mount. No direct SQLite writes. Invoke `back`’s CPCP seam for all domain changes. |
| 5 | L8 completion command handling from reconciliation | `back` via CPCP; initiated by `backjob` | Currently dead path | The command authority belongs with the Rails application; the worker should not become a second writer. This preserves trust and audit boundaries while allowing worker failure isolation. | Set the intended backend address through configuration and require observable failure, not a rescued silent envelope. Exact remediation is not specified beyond the brief. |
| 6 | Durable event repository | `persist` | No container today | Event durability has a distinct storage and recovery lifecycle from provider routing. It must not be owned by `switch-bus`, which has a volatile/data-plane concern and provider-key exposure. | `persist` owns the physical event repository. Event schema, database engine, and API are not established. |
| 7 | Event bus / pub-sub transport | `switch-bus` | No built bus stated; current `switch` is LLM plane | Bus transport and event repository have different failure and durability semantics; keeping transport separate from repository avoids making provider routing the source of truth. They may share one process only if the same deployment/failure/resource boundary is later demonstrated; that evidence is not established. | Target name `switch-bus` refers to the bus role, not NVIDIA Switchyard and not an event store. |
| 8 | LLM request routing, provider adaptation, protocol translation, and data-plane health | `switch-bus` (Node lineage; alternatively rename to `llm-plane`) | `switch` | These functions already share one Node process, provider-facing resources, runtime lifecycle, and deployment boundary. They should not gain event-store authority merely because they carry messages. | Preserve Node implementation unless a later decision replaces it. No Rust assumption. |
| 9 | Provider credential runtime brokering | `vault` | No container | Credentials require a separate trust boundary from arbitrary LLM routing and from domain/event state. Vault failure should fail secret acquisition, not corrupt domain state; its resource/lifecycle/deployment profile is narrow. | No shared writable volume with `back`, `backjob`, `mind`, `switch-bus`, or `persist`; no event participation; no secret values in logs/events; explicit caller allowlist. |
| 10 | Human credential entry, configuration UI, and admin API | `config-admin` | Inside `switch` on 8790 | Human-facing admin traffic has a different exposure and trust boundary from pod-internal model traffic. Isolating it reduces the published attack surface of the LLM plane and allows an independent UI lifecycle. | Publish only `config-admin`; preserve a durable operator-managed store during migration. Exact authentication/authorization is not established. |
| 11 | Provider-source refresh, verification, and test controls | `config-admin` calling `vault` and `switch-bus` | Inside `switch` today | These are administrative functions, not inference-path functions. Their lower availability and higher operator privilege should not share the data-plane process. | API ownership and call authorization are target design decisions; exact endpoint relocation is not established. |
| 12 | Agent execution/client behavior | `mind` | `mind` | Agent execution has distinct resource consumption, failure behavior, and deployment cadence from the LLM gateway and Rails app. Keeping credentials out of it is a trust boundary. | `mind` holds no provider credential and names no model, as stated today. |
| 13 | RDF projection from Rails/domain state | `graph-projector` | No container; Storable projection unwired | Projection is asynchronous/derived work with independent failure and resource characteristics. It must not become the authority or block Rails writes. | Reads authoritative state/events and writes only derived RDF. Exact trigger and consistency model are not established. |
| 14 | RDF graph storage and query serving | `graph-store` | `graph` | Storage durability and query-serving recovery are distinct from projection code; separating them prevents projection bugs from owning the graph store process. | Oxigraph remains the candidate store based on today’s `graph`; graph authority remains false. `graph-data` ownership and migration details are not established. |
| 15 | Effect execution | `effect-plane` | No container; tree exists | Effects can have external side effects and therefore need an independent trust, failure, resource, lifecycle, and deployment boundary from pure domain writes and projections. | Container ownership is recommended from the runtime name only; effect contracts, credentials, and side effects are not established. |
| 16 | Blob/object storage and blob access | `blob-store` or an external object-storage service | No container | Blob payloads have different storage, scaling, and lifecycle needs from relational/event/RDF state. A separate boundary prevents large payloads from consuming application or event-store resources. | The brief does not establish whether this is a container or managed external service; target container assignment is therefore **not established**. |
| 17 | Shape validation for application/L8 payloads | `back` at the command boundary, unless independent validation workload is later demonstrated | No running container stated | Validation is part of accepting a domain command and should share the application trust and request lifecycle unless it needs a separate resource or deployment cadence. | Placement in `back` is a target recommendation, not a fact about current code. Exact validators are not established. |
| 18 | Semantic editor and application-level semantic operations | `back` initially | No running container stated | The function is application/domain-facing and should not receive a separate container until independent trust, failure, resource, lifecycle, or deployment needs are demonstrated. | Runtime placement is not established by the tree; `back` is the least-assumptive target boundary. |
| 19 | ADR/graph/domain adapters | `back` for command-side adapters; `graph-projector` for projection-side adapters | No running container stated | Command-side adapters belong with the authoritative application boundary; projection-side adapters belong with derived projection work. This splits by authority and failure semantics rather than by gem directory. | Exact adapter partition is not established and must follow actual call paths. |
| 20 | Image provenance and attestation attachment | External OCI registry/release control plane, not a pod production container | No registry adopted | Provenance is a release/deployment control function, not runtime domain or inference behavior. It has a different lifecycle and trust boundary. | No registry is authorized/adopted. If a container is mandated later, its owner is **not established**. |
| 21 | NVIDIA upstream Switchyard runtime | No target pod container in this map | Not running | The upstream is a separate Rust project under a do-not-fork boundary. It cannot be merged into the Node service by name collision alone. | Relationship is coexistence as a separately versioned upstream dependency or a future replacement decision; no fork, convergence, or replacement is authorized. |

## Q3 — Switchyard naming and relationship

| Question | Decision |
|---|---|
| Do the two Switchyards converge into one container? | **No, not on the evidence given.** Their languages, provenance, and status differ: the current service is Node and running; NVIDIA’s upstream is Rust, a submodule, and not running. |
| Do they coexist as two production containers now? | **No.** The upstream is not running in the pod. A future coexistence deployment is possible but not established or authorized. |
| Does one replace the other now? | **No.** The brief says convergence, coexistence, and replacement are undecided. |
| Only safe relationship under the do-not-fork boundary | Treat them as two separately named, separately versioned artifacts. Integrate with the upstream only through its supported public interfaces and packaging boundaries. Do not fork or silently absorb its source into the Node service. |
| Recommended names | Rename the current Node service/container to `llm-plane` or `switch-bus` depending on whether it actually gains bus transport. Name the upstream `nvidia-nemo-switchyard` or `nemo-switchyard-upstream`. Never use bare `switchyard` for both. |

## Q4 — Rails-based RES and event-store placement

| Option | Assessment | Decision evidence required |
|---|---|---|
| (i) Rails RES Ruby library inside `back`’s image | **Not available today:** the library has zero hits in this repo. It would couple event persistence to the Rails application image and its storage boundary. It can be a transitional implementation only if the application remains the sole writer and event data is not confused with the bus. | Add the actual dependency and demonstrate required event semantics, replay/recovery requirements, throughput, retention, and operational ownership. None is established by the brief. |
| (ii) Separate event-store container | Best fit for the adopted bus/repository split. `persist` owns durable event storage; `switch-bus` carries transport and does not become the source of truth. | Demonstrate a stable event API, recovery/backup procedure, ordering/idempotency requirements, and operational need for independent lifecycle/failure/resource scaling. |
| (iii) Rust reimplementation | **Reject for now.** The brief identifies it as a premature proposal, and no code is stated. Rust is also associated with NVIDIA’s separate upstream, creating another naming and ownership hazard. | Only reconsider after option (ii) has measured bottlenecks or hard runtime/operational requirements that a supported implementation can satisfy without forking an upstream. |
| **Pick** | **Choose (ii), implemented as `persist` owning the durable event repository.** Keep any temporary Rails-side event-writing adapter behind `back` if needed; do not call `switch-bus` the event store. | The exact interim adapter is not established. |

## Q5 — Vault migration: what moves and what stays

| Item | Move out of current `switch` `/state`? | Target owner | Reason |
|---|---:|---|---|
| Provider secret values | Yes | `vault` durable secret store/broker | Separates credential trust from LLM routing. |
| Human credential-entry workflow | Yes, functionally | `config-admin` → `vault` | The UI remains the operator path, but the secret is submitted to Vault, not stored by the data plane. |
| Provider source metadata, refresh, verification, and test controls | Yes, functionally | `config-admin`, with authorized calls to `vault`/`llm-plane` | These are administrative controls. |
| LLM routing, provider calls, translation, and health | No | `llm-plane` / `switch-bus` | They remain in the Node LLM-plane lineage, but obtain credentials through Vault. |
| A credential durability mechanism | No | `vault` storage, with operator-preserved durability | Keys must survive `down -v`; this must not depend on a named volume that the prescribed command deletes. Exact storage mechanism is not established. |
| Domain state, event repository, graph state | Must never move into Vault | `back`/`persist`/`graph-store` | Vault is not a persistence co-owner and must not participate in events. |

| Migration order | Required action | Must be observable before next step |
|---:|---|---|
| 1 | Deploy `config-admin` with the operator UI and preserve the existing 8790 path or an equivalent temporary compatibility route. Do not remove the existing entry path. | An operator can open the admin surface and enter a test credential without `llm-plane` being unavailable. |
| 2 | Deploy Vault with durable, operator-managed storage that survives `down -v`; import/copy credentials without deleting the current bind-mounted source. | A read-back test proves the credential is available to an authorized caller without exposing its value in output. |
| 3 | Change `llm-plane` to request credentials from Vault through an allowlisted interface. | A provider test succeeds through `llm-plane`; logs and events contain no secret values. |
| 4 | Run dual-read or controlled fallback from the old bind mount only as a temporary migration measure. | Repeated provider calls succeed after restart and after the relevant compose teardown test; fallback usage is measured. |
| 5 | Disable new writes to `switch` `/state`, retain a rollback copy, and keep the UI pointed at Vault. | A newly entered key appears in Vault and is used successfully; no new credential is written to the old location. |
| 6 | Remove old credential reads and only then remove the bind mount. | Provider tests and operator key-entry tests pass after the old mount is absent. |

The exact Vault product, encryption mechanism, authentication mechanism, and backup process are **not established**. The non-negotiable sequencing constraint is that the new operator entry path and durable Vault storage work before the old path is removed.

## Q6 — Config UI boundary decision

| Argument | Consequence |
|---|---|
| Keep it inside the LLM-plane container | Fewer deployment units and no immediate internal API boundary. However, the only host-published surface remains co-resident with provider credentials and inference routing; an admin/UI fault or compromise shares a process boundary with the data plane. |
| Split it into its own container | Adds an internal API boundary and a new deployment unit, but separates host-facing administrative trust from pod-internal inference, permits independent lifecycle/deployment, and makes Vault migration possible without keeping credentials in the LLM process. |
| Decision | **Split into `config-admin`.** The security/trust and exposure difference is material, and the UI is the credential-entry path. Publish only `config-admin`; keep `llm-plane` on its pod-internal data-plane port. |
| Caveat | Authentication, authorization, CSRF protection, and exact route ownership are **not established** by the brief and require separate design evidence. |

## Q7 — First cutover and sequencing of provenance work

| Stage | Decision |
|---|---|
| First cutover step | **Make `backjob` storage-isolated and route its reconciliation completion through a functioning `back` CPCP endpoint.** Remove its `mind-data` mount in the target compose design, configure the backend address explicitly, and eliminate direct `Reconciliation.create!` as the worker’s write path. |
| What must be true before it | A working CPCP completion contract must be identified; `back` must be able to accept the command; the worker must have no direct database mount; success/failure must be observable rather than silently rescued; rollback must preserve existing reconciliation data. The exact contract and test command are **not established**. |
| Observable evidence | A controlled reconciliation job causes the expected row/state transition through `back`; the worker has no writable SQLite path; a deliberately unavailable `back` produces a visible failed completion and retry/error signal rather than a printed never-raise envelope; no second-writer behavior is observed. |
| Why this first | It fixes a confirmed correctness and authority violation before introducing more containers. It also reduces the risk of migrating broken write semantics into `persist` or an event bus. |
| Provenance/attestation versus topology | **Topology and writer-boundary correction comes first.** Digest pinning and provenance should be established before production promotion of each new target image, but the brief says no registry is adopted and no provenance system is built. Do not block the first correctness cutover on an unadopted registry; do not deploy new containers without recording immutable image identities by whatever currently approved release control exists. |
| Next boundary cut | Introduce `persist` for the event repository and define the domain-storage ownership/API boundary, while keeping `switch-bus` out of durable event authority. |
| Later cuts | Split `config-admin`; introduce Vault with the migration order above; then wire `graph-projector`; then evaluate effect/blob services based on demonstrated contracts and boundary needs. |

## Target container inventory

| Target container | Primary functions | Storage ownership | Host exposure | Status |
|---|---|---|---|---|
| `front` | Browser-facing DB-less page | None stated | Not established; today exposes 3000 internally/compose-level | Retain |
| `back` | Rails app, CPCP seam, command validation, application-level domain writes | Should not share a writable worker volume; exact physical store access is not established | Today port 3000 is exposed; target host publication is not established | Retain, correct authority |
| `backjob` | Reconciliation work and CPCP command initiation | None; no `mind-data` mount | None stated | Retain, isolate |
| `mind` | Agent client | None stated | None stated | Retain |
| `llm-plane` / `switch-bus` | Node LLM routing, provider adaptation, translation, health; bus transport only if actually implemented | No durable event repository; no provider-secret source storage after Vault migration | 8789 pod-internal only | Rename/split role; retain Node lineage |
| `config-admin` | Human configuration UI, admin API, credential-entry workflow | No direct secret authority after Vault migration | Sole published admin surface, replacing today’s 13001 route | New |
| `vault` | Narrow provider-secret broker and durable secret storage | Credential store only; durable mechanism not established | Pod-internal only | New |
| `persist` | Durable event repository and target physical persistence-plane ownership | Event repository; broader domain-storage scope requires confirmation | Pod-internal only | New |
| `graph-projector` | Derived RDF projection and graph adapters | No authoritative storage | Pod-internal only | New |
| `graph-store` | Oxigraph RDF storage/query serving | `graph-data` equivalent | Pod-internal only | Split current `graph` role |
| `effect-plane` | Effect execution | Not established | Not established | New if/when contracts are defined |
| `blob-store` | Blob/object persistence and access | Not established | Not established | Not established whether container or external service |
| Release registry/control plane | OCI image provenance and attestations | Registry-managed | Not a pod runtime surface | External/not adopted; no target container assigned |

## Hard boundaries to enforce

| Boundary | Rule |
|---|---|
| Application authority | `backjob` never directly writes Rails/domain SQLite rows. |
| Physical storage | No two independently failing production roles share a writable domain-storage volume. |
| Bus versus repository | `switch-bus` transports messages; `persist` owns durable event history. |
| Credentials versus runtime | `vault` brokers secrets; `llm-plane` consumes them; neither `mind` nor `backjob` receives provider keys. |
| Admin versus inference | `config-admin` is the host-facing admin surface; the LLM data plane remains pod-internal. |
| Graph authority | `graph-store`/`graph-projector` hold derived RDF only; Rails/domain state remains authoritative. |
| Upstream ownership | `nvidia-nemo-switchyard` remains separately named and unmodified under the do-not-fork boundary. |
| Provenance | Do not claim registry adoption or attestation coverage until it is actually configured and observable. |

## References

[1]: /home/ubuntu/upload/pasted_content_sTa6W0iaoxZTbabb7rDkX2.txt "User-supplied system brief"
[2]: https://github.com/RailsEventStore/rails_event_store "Rails Event Store repository cited in the brief"

All factual claims in this memo are bounded by [1]. Reference [2] is included only because the brief explicitly names it; no additional repository facts were used.

---

