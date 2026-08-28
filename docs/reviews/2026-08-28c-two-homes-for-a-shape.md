# Review: two homes for a shape, and the one nothing validates

**Date:** 2026-08-28
**Scope:** where the OSI Level 8 shape documents actually live, which of them the
runtime pins, and which of them any tool reads.

Review 2026-08-28b closed with the drift check reporting `5 shapes compared, 0
drift` out of 105. Checking what the other 100 were led somewhere else: **the
shapes with real runtime counterparts are not among the 105 at all.** They live in
a second directory that neither the SHACL gate nor the drift checker reads.

## The two homes

| | file | size | contains |
|---|---|---|---|
| canonical | `gems/osi-level-8-profiles/profile-9-.../osi-level-8-profile-9-ghis.shacl.ttl` | 17,678 B | the P9 domain-record shapes |
| runtime | `gems/rails-osi-level-8/data/osi-level-8/profile-9-ghis.ttl` | 25,509 B | 43 NodeShapes **including the operation shapes** |

They are **different documents**, not copies. `JourneyListPullShape` and
`PageGetPullShape` exist only in the runtime one. ADR 0022 moved profile shapes
into `gems/`, and ADR 0038 made the monorepo the single home for a gem -- this is
the same defect one level down, in the documents rather than the code.

## F1 -- HIGH -- nothing validates the directory the runtime actually pins

`gems/rails-osi-level-8/data/osi-level-8/` holds **6 TTL files, 101 NodeShapes,
2,273 triples**. Nothing reads them:

- Gate 2's `validate.py` globs `osi-level-8-profiles/profile-*/shapes/*.ttl`
- `check_shape_drift.py` globs the same directory
- a repo-wide search for `data/osi-level-8` in any `.py` or `.yml` returns nothing

And yet this is the directory `ProfileCatalog.default` is pointed at
(`config.shape_root = Engine.root.join("data/osi-level-8")`), so it is the file
whose SHA-256 lands in `shape_digest` on **every admission record** the seam
writes.

So the evidence trail cites, by digest, documents that no gate has ever parsed. I
checked they parse -- all six do -- but nothing in CI would notice if one stopped.

## F2 -- HIGH -- the pinned P1 and P4 shapes are Milestone-1 stubs

| shape file the catalog pins | triples | NodeShapes |
|---|---|---|
| `profile-1-cyborg-channel.ttl` | **5** | 1 |
| `profile-4-durable-execution.ttl` | **5** | 1 |
| `profile-9-ghis.ttl` | 1,237 | 43 |
| `profile-11-meaning.ttl` | 785 | 48 |
| `session-operations.shacl.ttl` | 89 | 5 |

The P1 file says so itself: *"Stub closed shape for Milestone 1... Full SHACL via
mm-shacl-reader to be wired when the reader is vendored."* Meanwhile the
canonical P1 shapes in `osi-level-8-profiles` carry **324 triples across 7
NodeShapes** -- envelope, canonical-record, sync-intent, private-local, allow-list
template, and the session operations.

So an admission record for `note.create` cites `shape_digest` of a **five-triple
stub**, while the profile that Gate 2 validates has a full shape set the runtime
never sees. The digest is real, the pinning is real, and what it pins is a
placeholder.

## F3 -- MEDIUM -- my own drift check counts the wrong population

Yesterday's fix reports:

    shape files: 22   TTL shapes with enforceable constraints: 105   runtime cases: 15
    5 shape(s) compared, 0 drift(s)

Review 28b treated "5 of 105" as a coverage ratio and shipped the denominators
into the bundle so nobody would read it as a claim about the profile set. That
was right as far as it went, and it went to the wrong place: **the 105 are the
canonical shapes, and the shapes that have runtime counterparts are in the other
directory.**

The five compared are the session operations, which are the one set that exists
in BOTH homes -- because I copied the file into `data/osi-level-8/` when I added
them. That is why they compare and nothing else does. The checker is not
measuring 5 out of a comparable 105; it is measuring the only overlap that
exists, and the number 105 is a denominator from a population it cannot compare
against at all.

Pointing `SHAPE_DIRS` at both trees is a two-line change. It is deliberately not
made here: doing it would compare P9's 43 runtime shapes against
`Profile9::Request` allow-lists for the first time, which is a real audit with
real findings and belongs in its own pass, not appended to a review of the
checker that found it.

## What is NOT broken -- checked, because it is the obvious thing to assume

P9's runtime enforcement is good, and the divergence risk above has not bitten:

- `Request.closed!(params, LIST_KEYS)` refuses unknown keys -- `sh:closed true`
- `Request.require_cid!(params, "actorCid")` enforces the TTL's `sh:minCount 1`
- `LIST_KEYS = %w[actorCid status channel]` matches `ux:JourneyListPullShape`'s
  three properties exactly

Two mechanisms, applied per operation, agreeing with the document today. Nothing
compares them, so the agreement is maintained by hand -- but it IS maintained, and
saying otherwise would be the same overstatement F3 in review 28a already had to
correct.

## The pattern

Every finding here is an instance of one thing: **a document and the thing that
reads it drifted apart, and no third thing noticed.**

ADR 0038 made the monorepo the single home for a gem, after seven gems in two
places cost a day of misdirected work three times over. The shapes now have the
same problem: two P9 documents, one validated and one pinned, and the pinned one
unread by any tool. A stub can sit in the runtime home for months while the gate
reports green on a fuller document the server never loads.

The fix is the same as ADR 0038's: **one home.** Either the runtime reads the
canonical shapes directly, or `data/osi-level-8/` is generated from them with a
check that it is current -- the pattern `check_p10_alignment.py` already uses.
Until then, Gate 2 validates one set of documents and the seam pins another, and
only the first has ever been parsed by anything.
