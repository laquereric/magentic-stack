# mmg-effect-plane

**Plane C: where an effect lands, how durable it is, and what rollback means.**

```
Plane A  execution registration  -- reversible by teardown (a Cordis undo stack)
Plane B  domain truth            -- append-only; corrected by a NEW fact
Plane C  materialized effect     -- THIS: which immutable materialization is
                                    active, and how it got there
```

Rollback on Plane C is legitimate **only** as an explicit *fork-and-activate*
that appends an `EffectForkActivated` fact. It is never a rewind of domain truth.

The tempting argument is that an OCI digest is immutable, so selecting a prior
one deletes nothing. That is necessary but not sufficient. It becomes an
accounting trick the moment the live system silently abandons domain facts that
existed only inside the abandoned image or volume. Hence **C1**: a fork must name
the retained Plane B boundary it is reconstructable from, or it is refused.

Design: [`docs/MmgEffectPlaneDesign.md`](docs/MmgEffectPlaneDesign.md).

## The asymmetry the whole gem is about

| Stage | Mutable | Content-addressed | Survives container death | Rollback |
|---|---|---|---|---|
| `:source` | yes | git SHA | n/a | `:select_revision` |
| `:oci_image` | **no** | **digest** | yes | `:reinstantiate_verified_image` |
| `:container_layer` | yes | no | **no** | `:discard_and_recreate` |
| `:snapshot_image` | **no** | **digest** | while retained | `:fork_and_activate` |
| `:host_volume` | yes | no | yes | **`:not_by_image_selection`** |

Re-instantiating a prior digest rolls back everything in the **image** and
nothing in a **volume**. So the classic false rollback is: leave the original
read-write volume attached, instantiate an old snapshot image, and call the
result a rollback. `Fork.activation_event` refuses it:

```ruby
Mmg::EffectPlane::Fork.activation_event(..., volume_disposition: nil)
# => { ok: false, reason: :unresolved_writable_volume,
#      because: "... instantiating a prior image with the original RW volume still
#                attached is not a rollback" }
```

## Placement is evidence, never inference

A stage is never guessed from a path string. If topology evidence and the mount
inventory do not establish exactly one stage, the gem refuses — and that refusal
is the specific protection against reading a successful container restart as a
transaction rollback.

```ruby
Mmg::EffectPlane::Placement.declare(
  effect_id: "tx-9", target: "/app/state.db",
  topology_evidence: { stage: :snapshot_image, digest: "sha256:…", image_paths: ["/app"] },
  mount_inventory:   [{ path: "/app", writable: true, disposition: nil }]
)
# => { ok: false, reason: :ambiguous_mount,
#      because: "target is covered by both an image path declaration and an
#                unresolved writable mount (/app)" }
```

## C1–C9: a conjunctive contract

A capture that cannot prove even one condition may be a useful engineering
artifact, but it is **not** an effect-plane snapshot and cannot be called a
rollback point. `validate_contract` is all-or-nothing and reports *every* failed
condition, not just the first.

| | Condition | Refusal |
|---|---|---|
| C1 | authoritative-history retention | `:domain_truth_not_retained` |
| C2 | derived-state declaration | `:unclassified_store_authority` / `:sole_authority_store` |
| C3 | complete quiescence barrier | `:quiescence_unproven` |
| C4 | explicit volume closure | `:unresolved_writable_volume` |
| C5 | provenance closure | `:provenance_unbound` |
| C6 | secret and policy exclusion | `:forbidden_snapshot_content` |
| C7 | external-effect closure | `:external_effect_unclosed` |
| C8 | durable branch record | `:fork_not_recorded` |
| C9 | retention viability | `:retention_undefined` |

C2 carries two refusals on purpose: a store nobody classified is a different
failure from one classified as the **sole authority** for domain facts. Forking
the latter would discard Plane B truth.

C3 means a raw copy of a live SQLite WAL or a running graph store is not a
snapshot: every writer must be fenced and acknowledged, and every store must
return a consistency-safe capture receipt.

## `docker commit` is not an admissible release path

`mmg-k3s` admits a `Revision` only when its Release Packet verifies and binds to
the OCI image. A committed image has neither. So:

```ruby
S = Mmg::EffectPlane::Snapshot

S.admissibility({ digest: "sha256:…" })
# => { ok: false, reason: :provenance_unbound }

S.admissibility({ path: :rebuilt_release, release_packet_verified: true, binds_to_digest: "sha256:…" })
# => { ok: true, path: :rebuilt_release, admissible: true }        # production default

S.admissibility({ path: :attested_packet, attestation: "sig" })
# => { ok: true, path: :attested_packet, admissible: false,
#      requires: :control_plane_extension,
#      because: "… must not be presented as an admitted Revision" }
```

That last one is deliberately `ok: true`. The packet is **well-formed**; it is
simply a new artifact class that the current control plane does not admit.
Saying so is more honest than refusing it or silently promoting it.

## Addressable is not activatable

A snapshot retained for audit may still fail current provenance or policy.
`Fork.activatable?` keeps the two apart, so "cannot activate" never reads as
"gone", and a collected snapshot never reads as an unknown IRI:

```ruby
Mmg::EffectPlane::Reference.resolve(reference: ref, resolver: collected_resolver)
# => { ok: false, reason: :snapshot_collected,
#      former_snapshot_digest: "sha256:…", policy_reason: :expired }
```

`Reference.preview` asks the resolver for at most `max_bytes` **and** bounds
whatever comes back — a resolver that ignores the cap must not be able to flood a
caller with an unbounded database or graph.

## Modules

| Module | Job |
|---|---|
| `Vocabulary` | The closed sets: 5 stages, 5 classifications, C1–C9, mount dispositions, forbidden content, store roles |
| `Placement` | Which stage did this land on? Refuses on ambiguous or unevidenced placement |
| `Classifier` | `:reversible` / `:fork_reversible` / `:compensable` / `:irreversible` / `:refused` |
| `Snapshot` | The C1–C9 validator, the provenance ruling, and the declarative manifest |
| `Fork` | Activation events, receipt verification, addressable-vs-activatable |
| `Reference` | Bounded typed preview, resolution, tombstones |

## What this gem is not

No Docker client. No `docker commit` wrapper. No Kubernetes client. No OCI
signer. No RES writer. No store-specific SQLite or oxigraph code. No volume
copier. No image garbage collector. No policy engine.

The integration point is **evidence validation and a stable vocabulary**, never
command execution — adding execution would erase the boundaries that make these
classifications auditable. Orchestration stays with `mmg-k3s`, release packaging
with `mmg-to-oci`, image layout with `vv-docker-swap`, AR durability with
`mmg-durable`, and plugin lifecycle with dsh/Cordis.

## dsh seam

They compose, and a durable effect plane makes Cordis's in-process undo stack
**more** necessary, not less: an undo stack cannot name or restore out-of-process
durable state after process death, and an immutable snapshot cannot unhook a live
listener. The rule is that dsh may undo its Plane A work freely, but must ask
this plane to classify any write it wants to treat as durable or fork-activatable.

"Context per transaction" is a **correlation and policy boundary, not a snapshot
boundary**. One image layer per transaction is not the design; an unapproved
cadence is refused rather than costed:

```ruby
S.manifest(contract: contract_with(policy: { snapshot_rate_approved: false }), artifact: {})
# => { ok: false, reason: :snapshot_rate_unapproved }
```

## Boundary shape

Every public entry point returns `{ ok: true, … }` or
`{ ok: false, reason:, because: }`. No `Dry::Monads`. Refusals are used wherever
an answer would have to be invented.

## Test

```bash
bundle install
LANG=en_US.UTF-8 bundle exec rspec   # 75 examples, 0 failures
```

The suite implements the design's A01–A22 acceptance assertions with fakes for
topology evidence, barriers, append receipts, and resolvers. No Docker daemon is
required.

## License

Apache-2.0 (see `LICENSE`).
