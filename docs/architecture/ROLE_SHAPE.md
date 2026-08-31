# ROLE=shape — surface design (gap 6)

Measured 2026-08-31 from `689fb71`. **Design only. Not built.**

ADR [0049](../adr/0049-role-shape-serves-from-mounted-gems.md) already
decided that `ROLE=shape` is the interim serving surface, additive to
BACK's in-process enforcement. This document is the surface 0049 said
had to be designed against ADR [0045](../adr/0045-cpcp-is-the-shape-container.md)'s
list, not routed ad hoc.

No controllers, no routes, no gem changes in this change.

---

## What is actually there (so the table is not a wish)

| Thing | Measured |
|---|---|
| HTTP shape surface | **none.** `rails-cpcp` draws `POST rpc`, `GET cid.json`, `GET up`. `rails-osi-level-8` is an engine with no controllers and no routes. |
| Live resolver | `ProfileCatalog::SHAPE_MAP` (16 explicit rows) plus P9/P11 vocabulary expansion. Resolves via `Gem.loaded_specs` / `gems/<name>`. ADR 0044. |
| Gem catalogs | `Shapes::Level8.catalog` → `{}`. `Shapes::Application.catalog` → `{mind-pod: {}, folkcoder-pod: {}}`. `bundle(...)` always `unknown_bundle` ("step 4 skeletons"). **A retrieval that called these would serve nothing.** |
| TTL in the two gems | **7 files**: 2 in `shapes-level-8/bundles`, 5 in `shapes-application/contracts/mind-pod`. |
| TTL not moved | **52** in `gems/osi-level-8-profiles` (gap 23, not this job). |
| Enforcement | in-process in BACK (`Grounding.closed_shape_violations`). The TTL is the specification; CI runs pyshacl; the Ruby is what refuses a live request (`grounding.rb:123–126`). **This does not move.** |

The 7 files are the only bytes a v1 surface can tell the truth about.

---

## 1. ADR 0045's list, scoped against the gems

0045: Stage 2 owns publication, retrieval, trust metadata, compilation,
compatibility evidence, translation-profile metadata.

| 0045 item | From the gems today? | Needs building? | What it even means |
|---|---|---|---|
| **Retrieval** | **Yes, of 7 files.** `ProfileCatalog` already has gem, relpath, sha256, RDF IRI, `shape_artifact_id`. The bytes are in the image. | A serving path. Not a new payload. | Established: return the Turtle and its digest. |
| **Publication** | **No.** The gems are the source tree, not a registry. There is no package id, no immutable version, no publish operation. `VERSION = "0.0.0"` on both gems. Format core (`PackageId`, `Manifest`, …) is named in 0045 and lives across a repo boundary that 0045 **left open**. | Yes. | Established as a *job*; packaging direction is **not established** (0045 "Open, and not decided here"). |
| **Trust metadata** | **No.** What exists is a **byte digest** (`sha256` of the file, `shape_digest_v2`, `compiler_sha256` of `grounding.rb`). That is integrity of what we loaded, not signature, signer, provenance, or revocation. | Yes. Signer custody is **not established** (vault? SWITCH? neither today). | 0045's "trust" is the Manus list (signature, signer, revocation). Digest ≠ trust. |
| **Compilation** | **No compiler.** `grounding.rb` is a deliberate hand-written reproduction of the SHACL. `shape_artifact_id` names `ruby/grounding/...` but the "artifact" is that source file, not a generated backend. Serving it as "the compiled Ruby" would be a lie. | Yes. Manus: compiler interface from the start, Ruby first backend, not in the request path. | Established as intent; no artifact to serve. |
| **Compatibility evidence** | **No.** No semver policy, no breaking-change classification, no cross-version record. | Yes. | **Not established** what a compatibility record looks like for these two gems. |
| **Translation-profile metadata** | **No.** JSON-LD `@context` appears on some CPCP responses. There is no translation-profile package, no loss policy, no backend-capability record. | Yes. | **Not established** what ROLE=shape would serve under this name. |

**v1 is retrieval of the 7 files, plus a catalog that admits it is incomplete.**
The other five rows are not padded into a surface that sounds finished.

Owner, not this document: when (or whether) publication / trust / compile
become jobs, and the 0045 packaging direction.

---

## 2. CPCP, or plain HTTP?

Both, under `/_cpcp`. Retrieval is GET. Actions, when they exist, are RPC.
The bootstrapping circle is **not fatal**.

### The two specs people collapse

| Spec | Where it lives | Do you need it to *fetch TTL*? |
|---|---|---|
| **Envelope** — JSON-RPC 2.0, never-raise `{ok, error:{reason,because}}`, HTTP 200 | `CPCP_BEHAVIOUR.md`; already implemented in Ruby, Python, JS (gap 59) | No |
| **Operation shapes** — what a `note.create` payload may contain | the TTL | That is what you are fetching |

"You would need the spec to fetch the spec" is only true if those are the
same document **and** the only retrieval verb is a shaped `POST /_cpcp/rpc`.
They are not the same document. `GET /_cpcp/up` and `GET /_cpcp/cid.json`
already retrieve CPCP facts with no RPC body. A GET of Turtle is that class
of thing, not a new seam.

A greenfield Rust client implements the envelope from `CPCP_BEHAVIOUR`
(small) or by looking at `cid.json`. It fetches TTL with HTTP GET when it
wants to validate or compile. No cycle.

**What would be fatal:** `POST /_cpcp/rpc` `method=shape.get` whose params
must conform to `ShapeGetPullShape`, which is in the TTL being fetched.

**What would also be wrong:** a top-level `/shapes` outside `/_cpcp`. That
is a second seam. Gap 24 is what happens when a ROLE grows a surface it
was not supposed to own. 0045 kept Stage 2 at the existing seam on purpose.

### Argue CPCP-only

- 0045: `rails-cpcp` *is* the Stage 2 container.
- Vault's inbound edge is becoming CPCP (0046 amendment 2). Bus will have
  a CPCP interface (0050). MIND will serve one (0048). Consistency pulls
  this way.
- Never-raise, CID-grounded, one envelope for callers who already have it.
- Wrapping Turtle in JSON (`{"turtle":"@prefix ..."}`) works. It is just
  a bad fit for pyshacl, compilers, and `curl`.

### Argue HTTP-only

- The payload is static files. GET `text/turtle` is the native retrieval.
- A Python/Rust caller fetching a specification should not need a CPCP
  stack. pyshacl wants a graph, not an RPC envelope.
- Gap 59's non-Ruby callers exist, but they speak CPCP for *operations*,
  not for downloading the protocol definition.

HTTP-only as a *second root path* loses 0045's seam. HTTP-only with no
RPC forever also cannot grow publication/trust later without inventing
a second protocol.

### Recommendation

| Verb | Path class | Serves |
|---|---|---|
| `GET` | `/_cpcp/up` | liveness; **shape** artifact names, not BACK's `note.create` list |
| `GET` | `/_cpcp/shapes.json` | catalog: for each of the 7 files, `{digest, gem, path, rdf_iri, retrieval}` |
| `GET` | `/_cpcp/shapes/sha256:<digest>` | `text/turtle` bytes. Integrity is the digest in the URL. |
| `POST /_cpcp/rpc` | **not in v1** | publication / trust / compile, *when those exist* |

Same engine mount, different **operation catalog** than BACK. ROLE=shape
draws `/_cpcp` and **must not** draw `note.create` (gap 24, exactly).
BACK keeps drawing the domain catalog and keeps loading the shape gems
in-process (0049). Shared `/up` stays on every ROLE.

`GET /_cpcp/shapes/sha256:…` is not "plain HTTP instead of CPCP". It is
the same kind of GET projection `cid.json` already is. Callers with a
CPCP stack are not required to use it; callers without one are not
blocked.

If an owner later wants retrieval *also* as RPC (`shape.get` returning
the Turtle), that can be added. It must not become the only path.

### ROLE=shape and the "only seam" sentence

Gap 20 already records that "the seam is the only write path" predates
the second CPCP speaker. The live invariant is **BACK is the only writer
of domain state**, not "only one process mounts `/_cpcp`". Shape joining
MIND / vault / bus as a CPCP speaker is consistent **provided** its
catalog is shapes, not notes.

That last clause is the route-gate expectation, not a hope.

### What v1 does not need

A database. Retrieval is gem-file reads. `ROLE=shape`'s entrypoint should
look like vault/front (`exec rails server`), not BACK (`db:prepare`).
Gap 60 (baked sqlite) is the next job; this ROLE must not grow a
dependency on a baked database the way FRONT accidentally did.

---

## 3. `osi.example`

Six live NodeShape IRIs are `https://osi.example/shapes/P1NoteCreate…`
(and P4). Three Turtle prefixes (`osi:`, `note:`, `p4:`) sit under
`osi.example` as well. Session / P9 / P11 already live on
`https://w3id.org/cpcp/osi8/…`.

The inventory is [`tooling/shacl/osi_example_blast_radius.md`](../../tooling/shacl/osi_example_blast_radius.md)
(49 hits / 12 files at `ab6e4f7`). Do not re-derive it. The load-bearing
fact: `shape_id` is stored on `osi_l8_contexts` and
`osi_l8_admission_attempts`, re-emitted on PULL and on the refusal wire.
Dispatch is the Ruby name, so a rename does not change admission and
**does** orphan history. No checker compares catalog IRI to TTL
NodeShape IRI.

`osi.example` is RFC 2606 reserved. Serving this container as if it were
that origin **publishes** a placeholder. Leaving the bytes unserved
keeps the defect stored.

### Options (none of these is a namespace ADR)

| | What | Cost |
|---|---|---|
| **A. Do not bind HTTP to the RDF IRI** (v1) | Catalog lists `rdf_iri` (possibly `osi.example`) separately from `retrieval` (`/_cpcp/shapes/sha256:<digest>`). The container does not claim to be `osi.example`. Clients fetch by digest. | Placeholder remains *inside* the Turtle. Honest. No rename. **This is v1.** |
| **B. Serve as origin for `osi.example`** | `GET https://<shape>/shapes/P1NoteCreateEffectShape` (Host or path maps the IRI). | Publishes the reserved name as if it were a real ontology. Every later rename is a broken URL *and* a broken RDF identity. |
| **C. Rename first, then serve** | Successor IRIs, mapping from the six old ones, dual-write or lookup for historical `shape_id`, a checker that catalog IRI == TTL NodeShape IRI. | ADR 0041 already forbade silent rename. **Owner decision — a namespace ADR.** Blast radius §Recommendation. Not this surface. |
| **D. Refuse to serve the 6 until C lands** | v1 catalog omits them; only `w3id.org` session/P9/P11 files go out. | The files that BACK actually admits `note.create` against would be the ones the shape service does not serve. That is a worse lie than A. |

**v1 takes A.** Serving bytes by digest is not "the specification's own
identifiers point at a placeholder domain" as an HTTP fact. The RDF
graph still contains `osi.example`; the catalog says so; the retrieval
URL does not pretend to be that IRI.

**C is required before any option that treats the RDF IRI as a URL this
container answers.** That is owner work. This document does not pick
successor IRIs.

---

## 4. What building v1 would touch (not done here)

When an implementation brief exists, and not before:

- `extract/entrypoint.sh`: `shape)` branch, no `db:prepare`.
- `routes.rb`: `when "shape"` mounts `RailsCpcp::Engine => "/_cpcp"` **and
  nothing else**. The engine's *declared operations* for this ROLE must
  be the shape catalog, not BACK's. How the engine selects the catalog
  per ROLE is an implementation detail; drawing BACK's `note.create` on
  shape is a FAIL of `check_role_routes.py`.
- `tooling/compose/role_routes.json`: new `shape` role. Checker discovers
  roles both ways; an undeclared ROLE fails.
- Both compose files: a `shape` service, **not host-published** until
  gap 61 says what the documented host entry point is. Pod-internal.
- Catalog builder reads `ProfileCatalog.default`, **not**
  `Shapes::Level8.catalog`. Groups by file digest (several shapes share
  one TTL). Declares `incomplete: true` and `unmigrated: 52` (or
  equivalent) so a client cannot mistake 7 files for the protocol.
- `GET` body is the file bytes. `Content-Type: text/turtle`. Digest
  mismatch is a 404, not a different graph.

Gap 23 (move the 52) stays its own job. v1 does not serve
`osi-level-8-profiles/` as if it were in the two gems.

---

## 5. Owner decisions this document will not take

| Decision | Why it is not mine |
|---|---|
| Namespace successors for `osi.example` | ADR 0041; blast-radius doc; durable `shape_id` |
| 0045 packaging direction (format core vs `app-shacl-store`) | already open in 0045 |
| When publication / trust / compile get built | no artifacts, no signer, no compiler |
| Whether the 52 unmigrated TTL are in the first catalog | gap 23 |
| Host-published port for shape | gap 61; FRONT `:13000` is the cautionary tale |
| Signer custody for trust metadata | vault vs SWITCH vs neither |

The CPCP-vs-HTTP call **was** asked for. The recommendation is in §2.

---

## 6. What this is not

- Not a relocation of Grounding. BACK still refuses.
- Not Stage 3 (`app-shacl-store`).
- Not a claim that `Shapes::Level8.catalog` is the resolver.
- Not authorization to build. 0045's "narrow Stage 2 contract comes first"
  still holds; this is that contract for **retrieval**, and an explicit
  non-contract for the rest of the list.
