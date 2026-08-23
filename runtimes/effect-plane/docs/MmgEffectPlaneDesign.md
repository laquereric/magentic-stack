<!-- Manus design spec, harvested 2026-08-22 from task dfFwvvQwBrLSBMUm3RY6KQ.
     Supersedes task Hzaiod3zBHyrPkMDiKyGYY (v1), whose brief mistranscribed
     dsh (DeepSeek Harness) as an unknown token "dch".
     Companions: CordisCompatibility.md, NooaCordisCrossReference.md,
     rails_image_optimization.md + laquereric/vv-docker-swap.
     Brief: .mm_tmp/manus/effect-plane-brief-v2.md
     STATUS: PROPOSED SPECIFICATION, NOT APPROVED. Gem not yet built. -->

# `mmg-effect-plane`
## Design specification: Magentic Stack deployment effect plane

**Status:** Proposed architectural specification  
**Author:** Manus AI  
**Scope:** Ruby gem design; not an implementation and not a port of dsh or NOOA  
**Evidence basis:** This specification distinguishes supplied repository facts from design decisions. It does not assume unprovided behavior of SwitchYard, `oMlx`, `Kvm`, OCI registries, Docker capture tooling, or the private `mmg-k3s` implementation.[1]

## Executive decision

> **`mmg-effect-plane` is a third plane, but only for durable materializations of execution state. Its rollback is legitimate solely as an explicit, durable, fork-and-activate operation; it is never a rewind of domain truth.**

The earlier two-plane rule remains intact. **Plane A** is execution registration: handlers, provider bindings, listeners, resources, and other in-process objects may be removed by a Cordis undo stack. **Plane B** is domain truth: it is append-only and is corrected through a later compensating fact, never through lifecycle teardown. The proposed effect plane is **Plane C: materialized effect state**. It records which immutable, deployable representation was selected, how it was produced, what authoritative history it covers, and which branch of materialization is now active.

An OCI image digest is immutable and content-addressable, so selecting a prior digest does not itself delete that digest or rewrite the image registry’s history. That observation is necessary but insufficient. It becomes an accounting trick if the resulting live system silently abandons domain facts which existed only in the abandoned image or volume. The valid operation is therefore not “rollback” in the sense of restoring the past. It is **fork activation**: append an `EffectForkActivated` fact that names the prior materialization as the newly active branch base, retains the superseded branch as addressable history, and ensures that every authoritative domain fact remains in the RES/RDF truth path.[1]

| Plane | Subject | Allowed reversal mechanism | What it must never claim |
|---|---|---|---|
| **A — execution registration** | Live process composition and runtime bindings | Teardown / Cordis undo, normally in reverse registration order | That a removed binding erased a business fact |
| **B — domain state** | Domain facts and the authoritative RES/RDF history | New compensating fact; replay from retained history | That an old fact was deleted or rewritten |
| **C — effect plane** | Deployable materializations, snapshot artifacts, active branch selection, and references | Append a fork-selection fact; instantiate an identified immutable materialization | That selection of an old materialization erased post-snapshot domain truth |

This makes the relationship precise. Plane C is **not a second domain store** and cannot authorize a domain rollback. It provides a bounded, durable replacement for the *environmental and derived-state portion* of a running system. A Plane C snapshot is safe only if the facts required to reconstruct, audit, and compensate its domain effects remain authoritative outside the snapshot.

## One job and explicit non-goals

> **One job:** `mmg-effect-plane` classifies the landing place and rollback class of an effect, then validates and describes durable, addressable materialization snapshots and explicit fork activations.

The gem deliberately does **not** orchestrate containers or Kubernetes, package releases, optimize OCI layers, operate model persistence for Active Record models, execute dsh plugins, decide model/tool policy, or become an event store. Those responsibilities remain respectively with `mmg-k3s`, `mmg-to-oci`, `vv-docker-swap`, `mmg-durable`/RES, dsh/Cordis, and the future Switch/action-catalogue surface described in the brief.[1]

| Concern | Owner | `mmg-effect-plane` contribution | What this gem must not do |
|---|---|---|---|
| Release construction and signing | `mmg-to-oci` | State the provenance evidence a snapshot must carry | Build FRONT/BACK releases, sign release packets, or choose an OCI layout |
| Deployment control | `mmg-k3s` | Provide an immutable snapshot/fork vocabulary that a future admission rule may consume | SSH, schedule, apply manifests, renew leases, or bypass admission |
| Layer accounting and sharing | `vv-docker-swap` | Declare each snapshot’s unique added layer identifiers and retention cost | Infer deduplication or optimize image layout |
| Domain durability | `mmg-durable` / RES / RDF | Require a retained authoritative history before a snapshot can be fork-activated | Emit or replay arbitrary AR model durability events itself |
| Runtime plugin lifecycle | dsh / Cordis | Give an external durable materialization boundary | Register plugins, unhook handlers, or replace the undo stack |
| Model-facing semantics | NOOA and the Model Interface | Expose durable addressable references and refusal semantics | Supply prompts, a model context, a tool catalogue, or authorization policy |

## 1. The five typed effect stages

The stage vocabulary is intentionally closed. An implementation must not infer a stage from a path string alone; callers must supply placement evidence from the runtime topology or a declared image layout. If the gem cannot determine whether a path is image-resident, a writable container layer, or a mounted volume, it **refuses to classify**. This is the critical protection against treating an apparently successful container restart as a transaction rollback.

| Symbol | Pipeline stage | Mutable in place? | Content-addressed identity | Survival semantics | Permitted rollback semantics | Principal cost / danger |
|---|---|---:|---|---|---|---|
| `:source` | Source tree / revision | Yes | Git SHA, when supplied | Exists independently of a container | **Select prior revision** for a new build; never assert runtime state was restored | A source checkout does not restore generated data, deployment state, or external effects |
| `:oci_image` | Ordinary built Docker/OCI image | No | OCI image digest | Survives container death | **Re-instantiate a prior verified release image**; this is deployment selection, not domain rollback | Digest identity does not certify source provenance or admission by itself |
| `:container_layer` | Container writable layer | Yes | None supplied; treat as non-content-addressed | Lost when the container is destroyed | **Discard and recreate only**; no durable rollback claim | Ephemeral writes are torn or lost on failure and cannot be named safely as a snapshot |
| `:snapshot_image` | Image-resident snapshot data, committed as an immutable OCI artifact/layer | No after creation | Snapshot OCI digest plus its provenance packet | Survives container death while retained | **Fork-and-activate a prior attested snapshot**, subject to the contract below | New layers can grow without bound; a digest alone is not safe provenance, consistency, or secret hygiene |
| `:host_volume` | Docker host environment volume | Yes | No content-addressable identity supplied | Survives container death and image replacement | **No image rollback.** Only a separately declared, consistent volume snapshot/clone plus a fork event could restore it | It escapes image selection; persistent writes can make a purported image rollback false |

The table preserves the supplied asymmetry: an earlier image digest restores what is in the image and restores none of the attached volume. A container writable layer is also not a legitimate durable snapshot merely because `docker commit` can turn some of its bytes into an image. The effect plane records the semantic distinction between a **running-layer capture attempt** and an **attested, quiescent snapshot artifact**.[1]

### 1.1 Effect classes

The stage provides a default class, but a complete classification also needs the authority and externality of the affected data. `mmg-effect-plane` therefore uses three outcomes.

| Classification | Meaning | Typical outcome |
|---|---|---|
| `:reversible` | The effect changes ephemeral registration or a disposable, fully derived materialization with no unrecorded domain truth | Teardown or discard/recreate; this normally belongs to Plane A or `:container_layer` |
| `:fork_reversible` | The effect lands in an attested immutable materialization and all conditions for branch activation are satisfied | Append `EffectForkActivated`; instantiate the named image/snapshot into an isolated branch |
| `:compensable` | The effect has domain meaning or reaches another durable authority, but a later fact/action can correct it | Append a compensation fact; do not call it snapshot rollback |
| `:irreversible` | The effect has no safe inverse or placement is known to escape the snapshot boundary | Require explicit policy/authorization outside this gem; capture a receipt if available |
| `:refused` | Placement, authority, quiescence, provenance, or volume behavior is unknown or contradictory | Return a never-raise refusal envelope and perform no classification |

A snapshot containing SQL and graph bytes is only `:fork_reversible` where those bytes are a valid materialization of retained authoritative truth. If the bytes are the sole record of a domain fact, the effect is at most `:compensable`; choosing an older image would hide a fact from the live materialization and violate Plane B. The effect plane must express this refusal rather than blessing the operation because an old image remains in a registry.

## 2. Legitimacy conditions for a snapshot fork

A digest is a valid **transactional materialization snapshot** only when all of the following predicates are true. The word “transactional” is deliberately scoped: it means a consistent selection of the declared materialized stores plus branch activation. It does **not** mean atomic rollback of arbitrary remote systems, volumes, or domain history.

| ID | Required predicate | Required evidence | Failure result |
|---|---|---|---|
| `C1` | **Authoritative-history retention.** Every domain fact represented by the capture is retained in the authoritative append-only RES/RDF path, including the point from which the materialization can be reconstructed. | A caller-supplied `authority` declaration naming the retained source and its immutable cursor/checkpoint reference | `:domain_truth_not_retained` |
| `C2` | **Derived-state declaration.** Captured SQL/graph stores are declared as a materialization, projection, index, cache, or otherwise replayable state; they are not the sole authority for business facts. | Store-by-store role and reconstruction declaration | `:unclassified_store_authority` or `:sole_authority_store` |
| `C3` | **Complete quiescence barrier.** All writers for every included store have stopped or been fenced; in-flight work is drained or represented by a durable boundary; each store reports a consistency-safe capture completion. | Barrier identifier, participant acknowledgements, writer-fence evidence, store capture receipts, bounded time window | `:quiescence_unproven` |
| `C4` | **Explicit volume closure.** Every writable mount is declared `:excluded`, `:immutable_input`, or `:branch_seeded`. An active mutable host volume cannot silently remain attached to an image-fork activation. | Mount inventory and branch-volume policy | `:unresolved_writable_volume` |
| `C5` | **Provenance closure.** The immutable snapshot digest is bound to its base release, source/revision identity if known, store manifests, barrier evidence, and signer/attestation. | Attested snapshot packet or a rebuilt normal release packet | `:provenance_unbound` |
| `C6` | **Secret and policy exclusion.** Secret material, credentials, private homes, user uploads, queues, logs, and other disallowed operational bytes have been excluded or explicitly handled outside image storage. | Inclusion manifest and policy verdict | `:forbidden_snapshot_content` |
| `C7` | **External-effect closure.** Effects outside the declared snapshot boundary are either absent, idempotently fenced, or classified as compensable/irreversible with their own receipts. | External-effect manifest and per-effect classification | `:external_effect_unclosed` |
| `C8` | **Durable branch record.** Activation is appended before/with the deployment selection and preserves both parent and selected snapshot identities. | An `EffectForkActivated` event reference/receipt | `:fork_not_recorded` |
| `C9` | **Retention viability.** The snapshot and its parent/base artifacts have a retention owner, expiry policy, and resolvable reference behavior. | Retention declaration and digest reachability/hold evidence | `:retention_undefined` |

Conditions `C1`–`C9` are a conjunctive contract. A successful capture process which cannot prove even one condition may be useful as an engineering artifact, but it is **not** an effect-plane snapshot and cannot be called a rollback point.

### 2.1 Quiescence barrier: required shape

A raw copy of live SQLite WAL files or a running graph store is not enough. The supplied brief specifically identifies SQLite WAL and a running oxigraph as unsafe to snapshot mid-write.[1] The effect plane should not encode product-specific database commands it cannot verify. Instead it defines a **pluggable, attestable barrier protocol** with a strict result shape.

```ruby
# frozen_string_literal: true

module Mmg
  module EffectPlane
    module Snapshot
      module_function

      # Validates an already-obtained barrier and capture manifest. This module
      # does not pause a process, copy a database, run Docker, or sign an image.
      def validate_contract(contract:)
        # => { ok: true, snapshot: { ... } }
        # => { ok: false, reason: :quiescence_unproven, because: "..." }
      end
    end
  end
end
```

The workload-specific adapter must produce, at minimum, a barrier record with a monotonic barrier ID; the set of participating writers; a positive acknowledgement that new writes were fenced; a statement that in-flight writes were either drained or represented by a retained authority cursor; one successful **consistent capture receipt per store**; and an explicit resume/disposition record. A store is not covered because the container process is merely “quiet.” It is covered only when its own supported consistency mechanism has completed and its declared output digest is present in the capture manifest.

| Barrier phase | Required semantic result | Mandatory refusal if absent |
|---|---|---|
| **Prepare** | Enumerate stores, writers, mounts, and external effects in scope | `:snapshot_scope_incomplete` |
| **Fence** | Prevent new writes for every included store and identify all writer participants | `:writer_fence_missing` |
| **Drain / cursor** | Finish in-flight writes or bind them to the authoritative retained cursor | `:in_flight_write_unresolved` |
| **Capture** | Obtain a store-certified, consistent representation and its digest for each included store | `:store_capture_unverified` |
| **Verify** | Verify all listed store digests and exclusion list before image/artifact assembly | `:capture_manifest_mismatch` |
| **Release** | Resume writers only after the outcome is recorded as success/failure | `:barrier_disposition_missing` |

A failure must leave the old active materialization active and return a never-raise envelope. The gem may record an attempted capture receipt, but it must not generate a `:snapshot_image` classification from a partial capture.

### 2.2 Provenance: `docker commit` is not an admissible release path

The design’s decisive provenance answer is **no**: a bare `docker commit` output must not be passed to `mmg-k3s` as though it were a normal `mmg-to-oci` release. The supplied `mmg-k3s` facts say that a `Revision` is admitted only when a Release Packet verifies and binds to the OCI image; its agent vocabulary is intentionally tiny and it may refuse bad signatures, machine mismatches, stale epochs, expired leases, and out-of-namespace targets.[1] A committed image without a matching verified packet therefore fails the existing contract.

The safe design has two paths, with one clear default.

| Path | Artifact and admission model | Status | Intended use |
|---|---|---|---|
| **A. Rebuild from captured snapshot input — default** | A consistent capture produces a bounded snapshot payload/manifest. The normal release construction path turns that input into a signed, topology-bound release with the existing release-packet semantics. | Compatible in principle with the provided `mmg-to-oci` / `mmg-k3s` constraints, subject to their actual APIs | Production activation |
| **B. Attested `EffectSnapshotPacket` — future extension** | A distinct signed artifact binds `snapshot_image_digest`, base release digest, source identity if known, store manifests, barrier receipt, branch parent, exclusions, retention, and signer. A future `mmg-k3s` admission extension must verify this class explicitly. | **Not admitted by the stated current rule**; never masquerade as a Release Packet | Local/coding-harness use or future control-plane evolution |

Path A is the correct production default because it does not relax the current admission rule or invent provenance after the fact. Path B preserves the operator’s image-resident-snapshot idea but calls it honestly: it is a **new artifact class** requiring a new verifier and policy. `mmg-effect-plane` may validate a packet’s required fields, but it must not sign, package, or admit it. The present gem’s result should therefore be a declarative `SnapshotManifest` and an optional `EffectSnapshotPacket` schema, not a hidden `docker commit` command.

### 2.3 Layer cost and retention discipline

`vv-docker-swap` establishes that shared layers are counted once per distinct layer ID and that naïvely summing image sizes double-counts shared bytes. It also requires an identical digest-pinned parent and identically resolved common gems before closely related images can share the relevant layers.[1] `mmg-effect-plane` must rely on that accounting model rather than introducing a second size calculation.

Every accepted snapshot declaration must therefore include `base_digest`, `new_layer_ids`, `distinct_added_bytes` when available from the selected accounting provider, a `retention_class`, and a `retention_owner`. It must reject an unlimited retention policy for high-frequency snapshot classes unless an explicit policy module outside the gem authorizes it. Changing database bytes typically create new content; shared application layers do not make mutable state free. No threshold values are prescribed here because none were supplied.

## 3. Adjudication: volumes versus image-resident snapshots

The two supplied gem positions are not both directives for the same byte class. `vv-docker-swap` correctly keeps uploads, database data, caches, queues, and logs out of normal writable image layers; the effect-plane mechanism needs a durable, content-addressed materialization to fork. The correct resolution is a **per-class split with an explicit checkpoint transfer**, not a choice of one gem over the other.[1]

> **Application rule:** Keep operational and long-lived mutable data in declared external storage during normal execution. Copy only bounded, non-secret, consistently captured, replayable materialization state into a snapshot artifact at an explicit checkpoint; activate that artifact only with a fresh or branch-scoped writable state target, never by reusing a pre-existing mutable volume.

| Data class | Normal residence | Eligible for image/snapshot payload? | Activation rule | Reason |
|---|---|---|---|---|
| Application code and static dependencies | Built OCI image | Yes, already release material | Normal verified release selection | Natural immutable artifact content |
| Rebuildable SQL/RDF projection or bounded harness state | Volume or a controlled state location during execution | Yes, **only** after `C1`–`C9` | New branch container with no old mutable volume, or a declared fresh branch seed | This is the narrow transactional-materialization use case |
| Authoritative RES facts and authoritative RDF truth | Existing durable truth path | **No as sole authority** | Replay/reconstruct; compensate domain facts separately | Plane B must remain append-only |
| User uploads, private homes, credentials/secrets | Private/external storage | No | Preserve via their owning store and explicit access policy | Secrets and private data must not become OCI layers |
| Logs, caches, queues, scratch files | Volumes/external services/stdout as applicable | No | Recreate, drain, or use queue-specific semantics | They are operational state, not rollback truth |
| Large operational databases | Volume/external database | Usually no; only a bounded, explicit derived checkpoint is eligible | Database-specific clone/restore controlled outside this gem | Per-snapshot image layers are a poor bulk-data store |

This is a **per-class** decision first, not a blanket coding-versus-production decision. It yields a secondary **per-phase** bias: the coding harness may have small, bounded, disposable state suitable for more frequent snapshotting; production normally has larger and longer-lived operational volumes, so it should use rare checkpoints and release-level materialization. Neither gem is wrong. The unsound operation is to leave the original read-write volume attached, instantiate an old snapshot image, and label the result a rollback.

## 4. Proposed Ruby gem surface

The gem uses six small modules. It follows the stated substrate conventions: a frozen vocabulary, `module_function`, hash-based never-raise envelopes, explicit refusals rather than guessed answers, and no `Dry::Monads`.[1] The signatures below establish the public semantic contract; adapter construction, canonical serialization, OCI assembly, RES append mechanics, and signer implementation remain with their owning gems.

```ruby
# frozen_string_literal: true

module Mmg
  module EffectPlane
    module Vocabulary
      module_function

      STAGES = {
        source: {
          mutable: true,
          content_address: :git_sha,
          survival: :independent_of_container,
          rollback: :select_revision
        }.freeze,
        oci_image: {
          mutable: false,
          content_address: :oci_digest,
          survival: :survives_container_death,
          rollback: :reinstantiate_verified_image
        }.freeze,
        container_layer: {
          mutable: true,
          content_address: nil,
          survival: :lost_on_container_death,
          rollback: :discard_and_recreate
        }.freeze,
        snapshot_image: {
          mutable: false,
          content_address: :oci_digest,
          survival: :survives_container_death_while_retained,
          rollback: :fork_and_activate
        }.freeze,
        host_volume: {
          mutable: true,
          content_address: nil,
          survival: :survives_container_death,
          rollback: :not_by_image_selection
        }.freeze
      }.freeze

      CLASSIFICATIONS = %i[
        reversible fork_reversible compensable irreversible refused
      ].freeze

      def stage(value); end
      def classification(value); end
    end

    module Placement
      module_function

      # Requires topology evidence; never identifies a stage by guessing from a path.
      def declare(effect_id:, target:, topology_evidence:, mount_inventory:); end
    end

    module Classifier
      module_function

      # placement is the accepted output of Placement.declare.
      # authority describes whether affected bytes are materialized or authoritative.
      def classify(effect:, placement:, authority:, external_effects:); end
    end

    module Snapshot
      module_function

      # Validates C1-C9 against evidence produced by workload-specific adapters.
      def validate_contract(contract:); end

      # Produces a declarative manifest; does not run Docker, create an image,
      # sign an artifact, or deploy a revision.
      def manifest(contract:, artifact:); end
    end

    module Fork
      module_function

      # Builds the event payload that the RES owner must append. It cannot activate
      # an unrecorded branch and it must name both the parent and selected snapshot.
      def activation_event(branch:, parent_snapshot:, selected_snapshot:, reason:, authority_cursor:); end

      # Validates a caller-provided append receipt against the proposed activation.
      def verify_activation(event:, append_receipt:); end
    end

    module Reference
      module_function

      # Supplies typed, bounded access to a retained snapshot result through an
      # explicit resolver supplied by the owning reference protocol.
      def preview(reference:, resolver:, max_bytes:); end
      def resolve(reference:, resolver:); end
      def tombstone(reference:, collection_receipt:); end
    end
  end
end
```

### 4.1 Envelope requirements

All public calls return one of the following shapes. `reason` is a stable symbol; `because` is a short explanatory string suitable for a caller or model-facing adapter. The implementation must not use exceptional control flow for invalid input or an unsupported semantic claim.

```ruby
{ ok: true, placement: { stage: :snapshot_image, evidence: { ... } } }

{ ok: true, classification: :fork_reversible,
  rollback: :fork_and_activate, conditions: %i[C1 C2 C3 C4 C5 C6 C7 C8 C9] }

{ ok: false, reason: :ambiguous_mount,
  because: "target is covered by both an image path declaration and an unresolved writable mount" }
```

`Placement.declare` accepts only a target, topology evidence, and mount inventory sufficient to establish a single stage. `Classifier.classify` must return `:refused` where a target is unplaced, its mount topology is ambiguous, the authority of the store is unknown, or an external effect lacks closure. `Snapshot.validate_contract` is an all-or-nothing validator for `C1`–`C9`; it does not attempt best-effort capture.

`Snapshot.manifest` produces data which a packaging/admission owner may sign and bind. Its minimal proposed schema is below. Field names are a design proposal, not a claim that `mmg-to-oci` or `mmg-k3s` currently accepts them.

| Field | Meaning |
|---|---|
| `snapshot_id`, `snapshot_image_digest` | Snapshot’s stable logical identifier and OCI identity once assembled |
| `base_release_digest`, `base_image_digests` | Exact release/materialization ancestry |
| `source_ref` | Git SHA or explicit `nil`/`unknown` status; absence is never silently filled |
| `branch`, `parent_snapshot` | Fork identity and history relation |
| `authority_cursor` | Immutable reference to retained Plane B truth used for reconstruction/audit |
| `stores` | Each captured store’s role, capture digest, consistency receipt, and reconstruction declaration |
| `barrier` | Barrier ID, writers, acknowledgements, time bounds, and disposition |
| `mounts` | Every writable mount and its `excluded` / `immutable_input` / `branch_seeded` disposition |
| `external_effects` | Classification and closure receipts for effects outside the artifact |
| `exclusions` | Explicit non-inclusion list, including secrets/private data where relevant |
| `layers` | Base digest, new distinct layer IDs, and accounting-provider output where available |
| `retention` | Owner, retention class, expiry/hold, and garbage-collection behavior |
| `attestation` | Signature/packet reference supplied by the signing owner |

### 4.2 Deliberately left out

The gem contains no Docker client, no `docker commit` wrapper, no Kubernetes API client, no OCI signer, no direct RES writer, no schema-specific SQLite/oxigraph code, no generic volume copier, no image garbage collector, and no policy engine. Adding those would erase the boundaries that make classifications auditable. The integration point is evidence validation and stable vocabulary, not command execution.

## 5. Fork activation semantics

An approved activation creates a new materialized branch. It does not mutate the selected snapshot and does not erase the branch which was previously active. The event should have a shape analogous to the following; its actual append and RDF representation belong to the existing RES/RDF owner.

```ruby
{
  type: :EffectForkActivated,
  branch: "branch:production:billing:2026-08-22T12:00:00Z",
  parent_snapshot: "sha256:current-materialization",
  selected_snapshot: "sha256:prior-attested-materialization",
  authority_cursor: "iri-or-digest-of-retained-plane-b-boundary",
  reason: :operator_selected_recovery_point,
  volume_disposition: :fresh_branch_seed,
  activated_at: "supplied-by-event-owner"
}
```

The activation is valid only when the selected snapshot remains retained, its provenance verifies according to its artifact path, its declared authority cursor remains resolvable, and its volume disposition is satisfied. If any prerequisite fails, the deployment owner must retain the currently active branch and report a refusal. A past snapshot can be **addressable** after it ceases to be **activatable**; for example, it might be retained for audit but fail current machine or policy constraints. The effect plane should preserve this distinction.

## 6. IRI reference-protocol seam

The effect plane provides a concrete retention anchor for a result reference: an IRI may identify a result inside an immutable snapshot digest together with its branch, typed locator, and retention policy. The digest is not itself the IRI protocol. A model-facing reference protocol still needs an explicit resolver, bounded typed preview, stable failure envelopes, and an expiry/retention rule—the characteristics previously identified as important.[1]

| Reference component | Proposed role |
|---|---|
| `iri` | Stable logical identity of the result or materialized state |
| `snapshot_digest` | Exact immutable artifact that contains the referenced representation |
| `branch` | Materialization branch in which that representation was active or produced |
| `locator` | Typed bounded location within the artifact; never an unvalidated arbitrary host path |
| `media_type` and `schema_ref` | Preview/consumer typing contract |
| `retention` | Owner, expiry/hold, and collection behavior |
| `resolver` | Explicit external capability that maps the reference to retained bytes/metadata |

`Reference.preview` must ask the resolver for at most `max_bytes` and return typed metadata plus a bounded sample, never silently materializing an unbounded database or graph. `Reference.resolve` may return a capability/result handle according to the owning IRI protocol, but this gem does not define that protocol’s authorization model.

Garbage collection must not create a false “not found.” Before a collected snapshot becomes unreachable, the retention owner should retain a tombstone/collection receipt containing the former digest, IRI, collection time, and policy reason. Then resolution returns a stable refusal such as:

```ruby
{ ok: false, reason: :snapshot_collected,
  because: "the referenced snapshot was collected under retention policy",
  iri: "...", former_snapshot_digest: "sha256:..." }
```

This gives NOOA or a later model-facing reference layer an honest distinction between an unknown IRI, a retained-but-inaccessible IRI, an expired IRI, and a collected snapshot. It does not guarantee that a digest will be retained forever.

## 7. dsh seam: composition, not substitution

**The two systems compose. They do not duplicate one another, and a durable effect plane makes Cordis’s undo stack more necessary, not less.** dsh/Cordis has a narrow but indispensable in-process job: dynamic plugin registration, service bindings, per-process resources, and reverse-order teardown without a process restart. Its undo stack cannot name or restore an out-of-process durable state after process death. Conversely, an immutable snapshot cannot safely unhook a live listener, cancel a live registration, or update a plugin graph in a running process.[1]

| Concern | dsh / Cordis must provide | `mmg-effect-plane` provides |
|---|---|---|
| Live process mutation | Registration, scoped context, teardown, plugin update | Nothing; snapshots are not process lifecycle control |
| Execution safety | dsh permission engine, its sandboxing model, and its UI/RPC behavior | Classification of where a resulting effect landed; no permission decision |
| Durable materialization | Native dsh does not provide the stated OCI digest/branch contract | Attested snapshot contract, fork vocabulary, retention/refusal semantics |
| Reversibility | Ephemeral undo for execution registrations | Durable selection of an immutable materialization branch, never domain history rewrite |
| Audit / addressability | Runtime context and session mechanisms | Snapshot digest, provenance manifest, fork event, bounded result reference |

The composition rule is simple: **dsh may undo its Plane A work freely; it must ask the effect plane to classify any write it wishes to treat as durable or later fork-activatable.** dsh must still bring plugin execution, code loading, permissions, sandboxing, and its own context semantics. The effect plane must never claim to make a live dsh execution safe merely because an image snapshot exists.

### 7.1 Coding harness and production deployment configurations

The supplied sketch identifies dsh as the same toolset in both phases: an LLM builds the manifest in both; coding execution emits dynamic code with context scoped per use case, while production deploys static code with context scoped per transaction.[1] The effect plane should support both through policy inputs, not fork into two incompatible storage models.

| Dimension | Coding harness: dynamic code / per use case | Production: static code / per transaction | Effect-plane consequence |
|---|---|---|---|
| Baseline | A use case may begin from a declared disposable baseline snapshot | A transaction begins from a verified release/materialization reference | Both need exact base identity and unambiguous mount placement |
| Expected churn | Higher; experimental state may be short-lived | Lower for images; durable facts and ordinary data flows continue | Apply different retention and checkpoint policies, not different semantics |
| Safe reversion | Cordis teardown plus discard/recreate; optional explicit snapshot fork for bounded state | Compensate domain facts; controlled checkpoint fork for eligible derived state | Never equate generated dynamic code cleanup with a production data rollback |
| Context scope | Context correlates a use-case branch | Context correlates effects/receipts within a transaction | Context scope is an attribution boundary, not automatically an OCI layer boundary |
| Snapshot cadence | Explicit checkpoint only, with strict quota/retention | Release, batch, recovery-point, or explicit materialization checkpoint | One snapshot image per logical transaction is not the default or implied design |

**“Context per transaction” should be read as a correlation and policy boundary, not as a snapshot boundary per transaction.** Treating it as one image layer per transaction would produce the very layer growth, capture latency, and provenance burden the design is intended to control. The nearest sound interpretation is: every transaction carries an `effect_context` naming its base materialization, authority cursor, stage classifications, and receipts; only a separate explicit checkpoint policy may request a snapshot. If a use case truly requires a snapshot per transaction, it must declare a bounded state size, retention owner, quiescence mechanism, provenance path, and layer-cost budget. The classifier should otherwise refuse the snapshot request with `:snapshot_rate_unapproved` or `:retention_undefined`.

## 8. NOOA seam

A future NOOA-compatible layer would gain **durable pass-by-reference state**: an exact materialization digest, branch lineage, a typed locator, bounded preview behavior, stable failure envelopes, and retention/expiry semantics. That is materially useful for a model interface because it allows a result reference to point to a verifiable materialized representation rather than inline unbounded SQL/RDF data.

It would **not** gain a NOOA execution contract. The effect plane does not define model context lifetime, harness evaluation, action-catalogue exposure, tool authorization, non-deterministic engine state, prompt shaping, execution isolation, or semantic replay. A resolver can tell NOOA that a snapshot has been collected; it cannot decide whether a model may read it or whether an action should be offered. Those remain above this plane.

| NOOA-adjacent need | Effect-plane contribution | Still required elsewhere |
|---|---|---|
| Pass-by-reference result | Digest-bound IRI/reference with branch and retention | Authorization and the resolver implementation |
| Bounded inspection | Typed preview contract and maximum-byte parameter | Schema interpretation and model-visible rendering policy |
| Stable errors | Never-raise refusal/tombstone vocabulary | Broader protocol error taxonomy |
| Durable provenance | Base release, barrier, store/cursor, and fork references | Manifest evaluation and tool/action policy |
| Execution context | Correlation fields only | Actual NOOA context contract and harness semantics |

## 9. Acceptance assertions

The following acceptance table is intentionally semantic. It is suitable for a gem test suite using fakes for topology evidence, barriers, RES append receipts, accounting, and reference resolvers. It does not require an actual Docker daemon inside the unit-test boundary.

| ID | Given | When | Then |
|---|---|---|---|
| `A01` | A source target with supplied Git SHA | `Placement.declare` | It returns `:source`, `:select_revision`, and does not call the result a runtime restore |
| `A02` | An OCI digest bound to a verified release evidence object | Classification | It returns `:oci_image` and `:reinstantiate_verified_image` |
| `A03` | A target in a container writable layer | Classification | It returns `:container_layer` / `:reversible` only as discard-and-recreate, never a durable snapshot |
| `A04` | A target path matched by both an image declaration and an unresolved RW mount | Placement | It returns `{ ok: false, reason: :ambiguous_mount }` |
| `A05` | A mounted host volume | Classification | It never returns image-selection rollback; it returns `:irreversible`, `:compensable`, or a refusal based on supplied authority/clone evidence |
| `A06` | A SQL store with no writer-fence acknowledgement | Snapshot validation | It returns `:quiescence_unproven` and no manifest |
| `A07` | All included stores have store-certified capture receipts and all writers are fenced | Snapshot validation | It accepts the quiescence portion only; it still checks the remaining conditions |
| `A08` | A graph/SQL store declared sole authority for domain facts | Snapshot validation | It returns `:sole_authority_store` rather than `:fork_reversible` |
| `A09` | A captured store declared replayable with a retained authority cursor | Classification | It may be `:fork_reversible` only if every other condition is present |
| `A10` | A `docker commit` digest with no normal Release Packet or snapshot attestation | Provenance validation | It returns `:provenance_unbound` |
| `A11` | A normal rebuilt release artifact with exact binding evidence | Provenance validation | It accepts Path A without treating it as a raw commit |
| `A12` | An `EffectSnapshotPacket` presented to the stated current `mmg-k3s` admission contract | Integration test | It is not represented as an admitted `Revision`; the result records that a control-plane extension is required |
| `A13` | A snapshot manifest with private-home bytes, credentials, logs, or queues included | Snapshot validation | It returns `:forbidden_snapshot_content` |
| `A14` | A snapshot activation leaves an existing RW volume attached | Fork validation | It returns `:unresolved_writable_volume` |
| `A15` | A fork event names an old selected digest and the active parent digest | `Fork.activation_event` | It includes branch, parent, selected digest, authority cursor, and volume disposition |
| `A16` | A valid event payload without a matching RES append receipt | `Fork.verify_activation` | It returns `:fork_not_recorded` |
| `A17` | A snapshot exceeds policy’s declared layer/retention capability | Manifest validation | It returns `:snapshot_rate_unapproved` or `:retention_undefined`, not a guessed cost |
| `A18` | A retained result reference and a resolver that returns a 10 MiB body | `Reference.preview(max_bytes: n)` | The returned preview is bounded to `n` with typed metadata |
| `A19` | A reference whose snapshot was collected with a retained tombstone | Resolution | It returns `:snapshot_collected` plus former digest and policy reason |
| `A20` | A dynamic dsh plugin registration with no durable write | Integration contract | It is handled as Plane A and does not require a Plane C snapshot |
| `A21` | A production transaction context with no explicit checkpoint request | Integration contract | It records/correlates effects but does not create an image layer per transaction |
| `A22` | A domain correction after an activated old materialization | Domain contract | The correction is represented as a new authoritative fact, never by deleting the later branch or its RES history |

## 10. Operational sequence

The intended end-to-end sequence is declarative and deliberately leaves execution with its owners.

1. A runtime/harness declares an effect and asks `Placement` to identify its stage using topology/mount evidence.
2. `Classifier` evaluates materialization authority, externality, and stage. An unknown fact yields a refusal rather than a default.
3. A caller requesting a checkpoint obtains workload-specific writer fences and store-consistency receipts, then supplies them to `Snapshot.validate_contract`.
4. On success, `Snapshot.manifest` creates the complete declarative evidence bundle. The release/snapshot owner chooses Path A or, where supported, Path B.
5. The deployment owner independently verifies provenance and its own admission rules. This gem does not convert a manifest into permission to deploy.
6. If an earlier materialization is selected, `Fork.activation_event` is created and appended by the RES owner. Activation requires an isolated volume disposition and preserves the former branch.
7. The reference owner exposes eligible results using a digest-bound IRI/reference and enforces preview, resolver, retention, and tombstone behavior.

## 11. Risks the gem must surface, not hide

The operator’s mechanism is valuable only within the preceding constraints. The following failures are first-class refusal/observability cases, not implementation details.

| Risk | Why the raw mechanism fails | Nearest sound alternative |
|---|---|---|
| Non-reproducible committed image | A live `docker commit` has no demonstrated source/release provenance | Rebuild from an attested capture input through the normal release path |
| Torn SQL/RDF capture | Copying live bytes may represent no consistent store state | Workload-specific quiescence and store-certified capture receipts |
| Unbounded layer growth | Every changed snapshot may add unique state bytes despite shared code layers | Bounded checkpoint cadence, retention owner, accounting evidence, and quotas outside the gem |
| Provenance loss | Image digest alone does not show its base, source, store state, or barrier | Bind a normal Release Packet or a distinct attested `EffectSnapshotPacket` |
| Secrets baked into image | OCI layer retention and distribution enlarge exposure | Strict exclusion policy; keep secrets/private homes outside snapshot artifacts |
| Volume escape | Re-instantiating an image does not rewind attached volume data | Fresh branch-scoped seed/volume or explicit external clone semantics |
| Domain-history loss | Snapshot selection can hide facts not retained elsewhere | Require authoritative RES/RDF retention and use compensation for domain changes |
| External side effects | Remote API calls, messages, or already-observed actions are not in the image | Fence/idempotency/receipt/compensation policy owned above the effect plane |

## 12. Open questions and required repository confirmation

This document does not invent answers to the following. Each item is a prerequisite for final implementation rather than a reason to weaken the design.

| Area | Missing fact / decision required | Consequence until resolved |
|---|---|---|
| `mmg-to-oci` | Whether and how a two-image FRONT/BACK release can accept a capture payload and which image may contain eligible snapshot state | Path A remains a design seam, not an implementation commitment |
| `mmg-k3s` | Exact Release Packet schema and whether a new `SnapshotRevision` / `EffectSnapshotPacket` verifier may be introduced without expanding unsafe agent behavior | Path B is non-admissible under the supplied rule |
| RES/RDF | Exact event schema, canonical cursor form, and the authority relationship between retained RDF named graphs and captured graph data | `authority_cursor` must remain an abstract required field |
| Store adapters | The supported quiesce/capture/restore mechanisms for the actual SQL implementation and graph engine | No generic implementation may claim safe capture |
| Volumes | How a branch-scoped fresh volume is created, seeded, attached, and garbage-collected by the deployment owner | Image activation with existing RW volumes must be refused |
| Secrets | The repository’s secret classification, scanning, and image-distribution controls | Snapshot content policy cannot be finalized |
| `vv-docker-swap` | Exact accounting API and where retention/accounting policy lives | This gem can require accounting evidence but cannot compute it itself |
| SwitchYard | Routing contract, deterministic engine selection, egress policy, and where effect classification is invoked | No Switch integration should be inferred from its directory’s existence |
| `oMlx` and `Kvm` | Meaning, lifecycle, storage semantics, and whether either owns state relevant to the five stages | They must not appear in this gem’s typed vocabulary yet |
| dsh integration | The manifest schema through which plugins declare durable writes and whether coding harnesses have a safe checkpoint hook | The dsh seam remains a host-side adapter contract |
| Retention | Registry/OCI retention guarantees, legal/audit retention needs, GC authority, and tombstone storage | The reference protocol can expose expiry but cannot promise permanence |
| External effects | Required receipts/idempotency/compensation model for network-visible actions | “Transactional” remains limited to declared materialization state |

## Final recommendation

Build `mmg-effect-plane` as the narrow **semantic firewall** described here. Start with the closed stage vocabulary, placement/classification refusals, snapshot-contract validator, fork-event builder, and reference/tombstone interface. Use **rebuild-from-captured-input** as the production provenance route. Treat an attested committed-image snapshot as a future artifact class that remains non-deployable until `mmg-k3s` has a dedicated verifier.

The durable capability gained is real but bounded: a verified, addressable materialization can be reselected through an appended fork event. That supports dsh in both its dynamic coding-harness and static production configurations without pretending that image selection rewrites domain history, rewinds a mutable volume, or reverses arbitrary external effects. In the cases where it cannot make that distinction, the correct behavior of the gem is an explicit refusal.

## References

[1]: file:///home/ubuntu/upload/pasted_content_2GT2yQVUVZKVAAt5ZLbXoc.txt "Operator-supplied `mmg-effect-plane` brief, including FACTS A–E and deliverable requirements"
