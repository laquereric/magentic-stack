# Architecture Decision Records

One file per decision, numbered and **immutable once accepted**. Anything that
moves a boundary, changes a contract, or advances an upstream pin requires an
ADR.

Body format: Context -> Decision -> Consequences.

## These files are read by machines

An architectural rule an agent never reads is operationally dead. An agent does
not query a wiki; it reads the repository. So these files carry **YAML
frontmatter** that [`mmg-adr`](../../gems/mmg-adr/README.md) parses into a
queryable ledger and a grounded named graph:

    ---
    id: '0011'
    title: Publishing triples requires a grounded entry
    status: accepted            # proposed | accepted | superseded
    date: 2026-08-26
    subject_kind: gem           # protocol | profile | gem | tooling
    subject: mmg-graph
    components: [mmg-graph]
    paths:                      # the code this decision governs
      - gems/mmg-graph/lib
    enforced_by:                # the mechanism that enforces it
      - gems/mmg-graph/spec/execute_spec.rb
    supersedes: null
    superseded_by: null
    ---

**One home.** ADRs live here and nowhere else. The same rule written into three
files for three tools drifts at three different rates, and the agent that lands
on the oldest copy behaves the way the oldest copy says.

## Lifecycle

`proposed` -> `accepted` -> `superseded`, one direction only.

An accepted ADR is **never edited**. When conditions change it is superseded by
a new file that points back at it via `supersedes`, and the old file gains a
`superseded_by`. Decision history is a ledger, not a live document. `mmg-adr`
enforces this at the model, so an edit to an accepted body is refused rather
than silently absorbed.

## Splitting a bundled decision

`supersedes` and `superseded_by` are **lists**. One ADR can be replaced by two.

ADR 0003 is the case that forced it: it bundled a decision that was done (native
oxigraph) with one that was explicitly *not taken* (which ACIA vocabulary
survives), both under a single `Accepted`. Its own Correction section said the
first real step "is NOT yet taken" -- so the status was false for half the
record, and an agent reading it would have found a settled decision to build on.

It is now superseded by **0034** (accepted) and **0035** (proposed), each
carrying the status it has actually earned. Both edges are in the graph, so
neither half is unreachable from the record they replaced. A single-valued link
would have forced naming one successor and dropping the other -- the ledger lying
to keep its schema.

## The chain

Every ADR should name the mechanism that enforces it (`enforced_by`) and the
code it governs (`paths`). Decision -> constraint -> code. If any link is
missing you should be able to say exactly where the chain breaks, which is why
`Mmg::Adr::Chain.break_at` returns the missing link by name.

## Freeze baseline (2026-08-26)

ADRs 0004-0021 were **recorded retrospectively** from code that already existed.
They are dated the day they were written, not the day the decision was taken --
backdating them would make the ledger lie about its own history.

Four carried a **known chain break**. **All four are now closed**, and the
baseline is empty: every ADR in force names what enforces it and what it
governs, no declared path is dangling, and a spec asserts exactly that -- so a
NEW break is visible the moment it appears.

Recording the gaps honestly first was the point. Pretending the initial run was
clean would have meant pointing `enforced_by` at files that do not exist, which
is the failure mode this whole apparatus exists to catch. What follows is how
each one closed.

**0020 is CLOSED.** It was the most valuable of the four -- an import-boundary
rule is exactly what a fitness function should own -- and it is now
`adapters-sole-path-to-upstreams` in `tooling/boundary/check_boundary.py`, run by
Gate 1 on every push. ADR 0030 supersedes 0020 and states the scope, including
what the check does **not** catch.

**0011 is CLOSED.** `mmg-graph` had no specs; it now has 32, and writing them
found a real bug -- `Cpcp.publish` rolled its entry back only when no caller
had wrapped it in a transaction. ADR 0032 supersedes it.

**0017 was WRONG, and that is the more useful finding.** `vv-graph` was
recorded as having no spec suite. It has 38 files and 316 green examples. The
survey behind this baseline listed specs with `ls <gem>/spec/*_spec.rb`, which
only sees the top level, and vv-graph nests under `spec/vv/graph/`. A recursive
re-audit confirms vv-graph was the only gem affected. ADR 0033 corrects it and
leaves 0017 standing as written -- correcting by editing would hide the error
rather than fix it. **Count spec files recursively.**

**0001-0003 are MIGRATED.** The three legacy ADRs now carry frontmatter, paths
and `enforced_by`. The obstacle was the ledger's own rule: moving a status out
of the prose and into frontmatter changed `body_digest`, so the immutability
check refused the migration -- immutability protecting a typography choice
rather than a decision. Fixed where it belonged, in the digest: a legacy ADR's
title heading and its Status / Date bullets ARE metadata, and are now excluded
from the digest (scoped to the preamble, so a `- Date:` inside a section is
still decision text). **All three digests are byte-identical before and after**,
which is the evidence that only metadata moved. No body was edited.

Their enforcement was already there, unnamed: Gate 1's `check_boundary.py`
asserts 0001's tiers and 0002's pin records, Gate 4 proves the pins advance and
roll back, and `mmg-graph`'s `execute_spec` pins 0003's live `MM_OXIGRAPH_URL`.

Fixing it surfaced a second thing: Gate 1 Part A was **already failing on main**.
Its tier list still demanded `interfaces/`, `apps/` and `plugins/`, removed in the
one-home-per-gem restructure. OWN IT and FOLLOW THEM are still required; OFFICIAL
is now optional, because an empty tier is a fact about what is vendored, not a
boundary violation.

## Profile coverage (2026-08-26)

All eleven profiles have a record. Two things are worth stating plainly:

**Six are `proposed`, not `accepted`.** P2, P3, P5, P6, P7 and P8 ship closed
SHACL shapes that Gate 2 validates, but they are review-ready drafts -- five of
them Manus-authored with citations not independently verified -- and none has a
Ruby implementation. `proposed` is what that state is called. Marking them
accepted would make the lifecycle decorative.

**P10 no longer has an implementation and no shapes.** It used to: P10 (INTENT)
existed only as Ruby, making it the one profile invisible to Gate 2 -- enforced
by its implementation rather than by a shape the implementation is checked
against. ADR 0031 closed that with seventeen closed node shapes plus
`scripts/check_p10_alignment.py`, which fails the gate if the shapes and
`validator.rb` diverge in either direction. All eleven profiles are now validated,
and a spec asserts no profile directory ships without shapes.

## Index

| ADR | Subject | Decision |
|---|---|---|
| [0001](0001-ownership-boundary.md) | repo | Ownership is legible from the path |
| [0002](0002-self-referential-consolidation.md) | repo | One clone builds the stack |
| [0003](0003-acia-moves-to-mmg-acia.md) | ACIA *(superseded)* | ACIA naming and convergence |
| [0004](0004-osi-level-8-the-cyborg-layer.md) | osi-level-8 | Context is a PULL, Effect is a PUSH |
| [0005](0005-profile-1-cyborg-channel.md) | P1 | The minimal Cyborg channel |
| [0006](0006-profile-4-durable-execution.md) | P4 | Durable effects and receipts |
| [0007](0007-profile-9-acia-presentation.md) | P9 | Presentation as a closed component tree |
| [0008](0008-profile-11-meaning.md) | P11 | Meaning as a governed record |
| [0009](0009-rails-osi-level-8-decorates-cpcp.md) | rails-osi-level-8 | Decorates CPCP, never competes |
| [0010](0010-rails-cpcp-two-pod-mandatory.md) | rails-cpcp | Two pods, mandatory |
| [0011](0011-mmg-graph-publish-requires-grounding.md) | mmg-graph *(superseded)* | Publish requires a grounded entry |
| [0012](0012-mmg-blob-content-addressed-operations.md) | mmg-blob | Identity is the digest |
| [0013](0013-mmg-semantic-editor-whole-or-not-at-all.md) | mmg-semantic-editor | Writes offered whole or not at all |
| [0014](0014-mmg-adr-decisions-are-state.md) | mmg-adr | Decisions are state, not documentation |
| [0015](0015-vv-base-canonical-model-homes.md) | vv-base | One canonical home per platform model |
| [0016](0016-vv-blob-sqlite-content-store.md) | vv-blob | SQLite, not a filesystem |
| [0017](0017-vv-graph-triples-inside-rails.md) | vv-graph *(superseded)* | The graph is a projection of the rows |
| [0018](0018-vv-html-components-static-review-surface.md) | vv-html-components | Review without touching the renderer |
| [0019](0019-switchyard-content-blind-router.md) | switchyard-offline | Content-blind router holds the credential |
| [0020](0020-adapters-sole-path-to-upstreams.md) | adapters *(superseded)* | The only code that may reach upstream |
| [0021](0021-bin-is-the-repos-executable-surface.md) | bin | Baselines never reference a consumer |
| [0022](0022-profile-shapes-move-to-gems.md) | osi-level-8-profiles | Shapes are a gem-tier package |
| [0023](0023-profile-2-reference-passing.md) | P2 *(proposed)* | An IRI is a pass-by-reference handle |
| [0024](0024-profile-3-market-routing.md) | P3 *(proposed)* | Record the routing decision before crossing |
| [0025](0025-profile-5-biography-and-provenance.md) | P5 *(proposed)* | Omissions must be detectable |
| [0026](0026-profile-6-authorization-evidence.md) | P6 *(proposed)* | Authorization is structural evidence |
| [0027](0027-profile-7-observation-and-outcome.md) | P7 *(proposed)* | Measuring is not deciding |
| [0028](0028-profile-8-architectural-learning-loop.md) | P8 *(proposed)* | Assumptions inspectable, /learn gated |
| [0029](0029-profile-10-intent.md) | P10 *(superseded)* | An Effect is bound to its intent |
| [0030](0030-adapters-boundary-is-enforced.md) | adapters | The import boundary is enforced by Gate 1 |
| [0031](0031-profile-10-has-shapes.md) | P10 | Closed shapes, held in step with the validator |
| [0032](0032-mmg-graph-grounding-is-enforced.md) | mmg-graph | Grounding refusals are spec-enforced |
| [0033](0033-vv-graph-does-have-a-spec-suite.md) | vv-graph | Correction - 316 examples, not none |
| [0034](0034-native-oxigraph-backs-sparql.md) | mmg-graph | Native oxigraph; one graph URL |
| [0035](0035-acia-convergence-undecided.md) | rails-osi-level-8 *(proposed)* | The ACIA vocabulary question is open |
| [0036](0036-slt-dimensions-are-one-subject.md) | rails-osi-level-8 *(superseded)* | Profile 9 conforms; SLT drift check gated |
| [0037](0037-normalize-in-place-not-republish.md) | rails-osi-level-8 | Normalize in place, do not republish |
| [0038](0038-magentic-stack-is-closed.md) | magentic-stack | Closed monorepo; a gem here has no other home |
| [0039](0039-session-scoped-graph-entries.md) | mmg-graph | A grounded assertion may name a shared destination graph |
| [0040](0040-the-session-is-one-entity.md) | vv-base | One Session across human and agent actors; not authorization |
| [0041](0041-two-shape-gems-role-not-namespace.md) | shapes-level-8 | Two shape gems, split by role not namespace |
| [0042](0042-close-the-ruby-to-the-ttl.md) | closed-shape enforcement | The seam refuses what the protocol forbids |
| [0043](0043-retain-the-unreachable-shapes.md) | shape quarantine | Unreachable shapes are retained, not deleted |
| [0044](0044-ownership-wins-over-file-boundaries.md) | shape gem cutover | Ownership wins over file boundaries; resolve per shape |
| [0045](0045-cpcp-is-the-shape-container.md) | shape package control plane | CPCP is Stage 2; app-shacl-store is Stage 3 |
| [0046](0046-vault-is-not-the-config-ui.md) | SWITCH decomposition *(amended by 0047)* | VAULT is a separate container from CONFIG-ADMIN |
| [0047](0047-three-languages-container-boundaries-own-images.md) | developer cognitive load | Python/Rust/Ruby by container; container boundaries only; one image per container |
| [0048](0048-mind-serves-a-cpcp-seam.md) | mind | MIND serves its own CPCP seam; CPCP needs a language-neutral spec first |
