---
id: "0044"
title: Shape ownership wins over file boundaries; the runtime resolves per shape
status: accepted
date: 2026-08-30
subject_kind: protocol
subject: shape gem cutover
components: [shapes-level-8, shapes-application, rails-osi-level-8]
paths:
  - gems/shapes-level-8
  - gems/shapes-application
  - gems/rails-osi-level-8/lib/rails_osi_level_8/profile_catalog.rb
enforced_by: [tooling/shacl/check_shape_resolution.py, tooling/shacl/check_shape_digests.py, tooling/shacl/check_catalog_ttl_iri.py]
supersedes: null
superseded_by: null
---

# Shape ownership wins over file boundaries

## Context

Step 9 was specified as a file MOVE with two constraints that turned out to
contradict each other in this tree:

- the relocation unit is the **file** (the legacy `shape_digest` is SHA-256 of
  exact runtime-root file bytes, so bytes must not change), and
- the ownership unit is the **shape** (`owner` is per NodeShape, ADR 0041).

Measured from the manifest, those units disagree on two of five runtime files:

| file | owners |
|---|---|
| `profile-1-cyborg-channel.ttl` | application 4 |
| `profile-4-durable-execution.ttl` | application 2 |
| `session-operations.shacl.ttl` | application 10 |
| `profile-9-ghis.ttl` | **level-8 17 + application 26** |
| `profile-11-meaning.ttl` | **level-8 16 + application 32** |

Every whole-file destination was already forbidden. Into `shapes-application`
puts `JourneyShape` in the application gem; into `shapes-level-8` puts
`JourneyListPullShape` in the protocol gem; `SHAPE_GEMS.md` names both as things
that must not happen. Copying creates two active shape sources. Moving only the
clean three leaves the old location populated.

Separately, `ProfileCatalog.default(root)` takes ONE root and stores bare
basenames, so "repoint `config.shape_root`" has no answer when the destination
is two gems.

## Decision

**Split the two mixed files along the ownership line**, so each part lands in
its owning gem, and **replace the single `shape_root` with a per-shape
resolution map** in `ProfileCatalog`.

The file boundary is an accident of how the protocol was written down. Ownership
is a governance fact. Where they disagree, ownership wins and the file gives way.

## What this costs, stated plainly

The two split files get new file-level digests. That is a real break in the
guarantee step 6 established, and it is accepted here deliberately rather than
quietly:

- The **shape text** of all 43 shapes in those files is unchanged. Only the
  enclosing file differs.
- The other three files keep their legacy digests untouched.
- `shape_digest_v2` already carries an explicit `covers` declaration, written in
  step 6 precisely so a digest can say what bytes it is over. The split is where
  that declaration earns its keep: the old digest covered a file that no longer
  exists, and the record must say so rather than appear to have drifted.
- An old-to-new mapping is published for every relocated and every split file.

## Alternatives rejected

**Majority owner, keep files whole.** Cheapest: no new digests, no catalog
change. Rejected because it knowingly places 33 protocol shapes inside the
application gem and weakens ADR 0041 from a rule to a tendency. A rule that
yields whenever a file is inconvenient is not being enforced.

**Generated runtime bundle.** Sources split by owner, one assembled directory as
`shape_root`. Coherent, and closer to the compiler-interface direction. Rejected
for now because it introduces a third tree that must carry provenance and its
own equivalence checker -- the plan warns specifically against a third normative
source. It remains the natural next move if per-shape resolution proves
awkward.

**Stop the cutover.** Defensible: the enforcement gap is already closed and the
gems could stay empty. Rejected because it leaves the arc's stated destination
unreached while paying the cost of having built the skeletons.

## Consequences

- `config.shape_root` ceases to be the resolution mechanism. Anything reading it
  must move to the catalog map.
- Admission behaviour must be **identical** across the split; it is a
  relocation, not a semantic change.
- `check_shape_drift` must keep comparing the canonical tree against the
  relocated runtime shapes. Collapsing to one tree is still step 10.
- The 46 retained shapes (ADR 0043) move with their owners and stay listed.
- `ProfileCatalog::Entry#shape_iri` must equal a `sh:NodeShape` IRI in the
  TTL file the entry resolves (`check_catalog_ttl_iri.py`). Local name is
  not identity. This does not rename `osi.example`.
