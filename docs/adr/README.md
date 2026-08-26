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

## The chain

Every ADR should name the mechanism that enforces it (`enforced_by`) and the
code it governs (`paths`). Decision -> constraint -> code. If any link is
missing you should be able to say exactly where the chain breaks, which is why
`Mmg::Adr::Chain.break_at` returns the missing link by name.

## Freeze baseline (2026-08-26)

ADRs 0004-0021 were **recorded retrospectively** from code that already existed.
They are dated the day they were written, not the day the decision was taken --
backdating them would make the ledger lie about its own history.

Four of them carry a **known chain break**, recorded rather than hidden:

| ADR | Subject | Missing |
|---|---|---|
| 0011 | `mmg-graph` | no spec suite |
| 0017 | `vv-graph` | no spec suite |
| 0020 | `adapters` | nothing checks the upstream import boundary |
| 0001-0003 | legacy | no `paths` or `enforced_by` declared |

This is a freeze baseline: existing gaps are accepted debt and visible, and new
ones are what to argue about. Pretending the first run was clean would have
meant pointing `enforced_by` at files that do not exist, which is the failure
mode this whole apparatus exists to catch.

The most valuable of the four is **0020** -- an import-boundary rule is exactly
what a fitness function should own, and it is a dozen lines.

## Index

| ADR | Subject | Decision |
|---|---|---|
| [0001](0001-ownership-boundary.md) | repo | Ownership is legible from the path |
| [0002](0002-self-referential-consolidation.md) | repo | One clone builds the stack |
| [0003](0003-acia-moves-to-mmg-acia.md) | ACIA | ACIA naming and convergence |
| [0004](0004-osi-level-8-the-cyborg-layer.md) | osi-level-8 | Context is a PULL, Effect is a PUSH |
| [0005](0005-profile-1-cyborg-channel.md) | P1 | The minimal Cyborg channel |
| [0006](0006-profile-4-durable-execution.md) | P4 | Durable effects and receipts |
| [0007](0007-profile-9-acia-presentation.md) | P9 | Presentation as a closed component tree |
| [0008](0008-profile-11-meaning.md) | P11 | Meaning as a governed record |
| [0009](0009-rails-osi-level-8-decorates-cpcp.md) | rails-osi-level-8 | Decorates CPCP, never competes |
| [0010](0010-rails-cpcp-two-pod-mandatory.md) | rails-cpcp | Two pods, mandatory |
| [0011](0011-mmg-graph-publish-requires-grounding.md) | mmg-graph | Publish requires a grounded entry |
| [0012](0012-mmg-blob-content-addressed-operations.md) | mmg-blob | Identity is the digest |
| [0013](0013-mmg-semantic-editor-whole-or-not-at-all.md) | mmg-semantic-editor | Writes offered whole or not at all |
| [0014](0014-mmg-adr-decisions-are-state.md) | mmg-adr | Decisions are state, not documentation |
| [0015](0015-vv-base-canonical-model-homes.md) | vv-base | One canonical home per platform model |
| [0016](0016-vv-blob-sqlite-content-store.md) | vv-blob | SQLite, not a filesystem |
| [0017](0017-vv-graph-triples-inside-rails.md) | vv-graph | The graph is a projection of the rows |
| [0018](0018-vv-html-components-static-review-surface.md) | vv-html-components | Review without touching the renderer |
| [0019](0019-switchyard-content-blind-router.md) | switchyard-offline | Content-blind router holds the credential |
| [0020](0020-adapters-sole-path-to-upstreams.md) | adapters | The only code that may reach upstream |
| [0021](0021-bin-is-the-repos-executable-surface.md) | bin | Baselines never reference a consumer |
