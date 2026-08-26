# mmg-adr

**ADR-as-spec -- decision records as state the fleet reads, with a queryable
ledger and a grounded graph.**

An architectural rule an agent never reads is operationally dead. An agent does
not query a wiki; it reads the repository. Markdown files under `docs/adr/` fix
that, and leave a second problem: prose cannot answer *which accepted decisions
govern this path*, or *which of them name no enforcing test*.

`mmg-adr` parses those files into an ActiveRecord ledger and projects their
attributes into a **grounded** named graph, so the decision set is queryable.
The file stays the source of truth; the row is a projection carrying
`body_digest`, so drift between them is detectable.

## Use

    Mmg::Adr::Ingest.call(dir: 'docs/adr', repo_root: Rails.root)
    # => { ok: true, ingested: 21, records: ['0001', ...],
    #      chain_breaks: [{ adr_id: '0011', missing: :constraint }, ...],
    #      dangling:     [{ adr_id: '0009', paths: ['gems/x/app'] }] }

Never raises -- it is a boundary. A governance index that takes the process down
on one malformed file is a governance index nobody leaves switched on.

## What it enforces

**The lifecycle is a ledger.** `proposed` to `accepted` to `superseded`, one
direction only. The body of an accepted record cannot change; superseding
requires naming the successor. Editing an accepted decision in place destroys
the reason the ledger was worth keeping, so `Record` refuses it.

**The chain is named, not scored.** `Chain.break_at` returns `:decision`,
`:constraint` or `:code` -- the first missing link in *decision to constraint to
code* -- because a boolean tells you something is wrong and leaves you to find
out what.

**Dangling paths are findings.** A dead ADR is worse than none: it stays in an
agent's search reach and is obeyed after the code it governs has moved. Every
path an ADR declares must resolve.

**Attributes are grounded.** Triples are published into the named graph of a
persisted `Mmg::Graph::Entry`, which carries a date, a name and a description.
`Mmg::Graph::Execute.publish` refuses a bare graph name, so there is no path
here that writes a node no record accounts for (ADR 0011).

## Format

YAML frontmatter for the machine, Nygard's Context / Decision / Consequences for
the human and the model:

    ---
    id: '0011'
    title: Publishing triples requires a grounded entry
    status: accepted
    date: 2026-08-26
    subject_kind: gem        # protocol | profile | gem | tooling
    subject: mmg-graph
    components: [mmg-graph]
    paths:                   # the code this decision governs
      - gems/mmg-graph/lib
    enforced_by:             # the mechanism that enforces it
      - gems/mmg-graph/spec/execute_spec.rb
    supersedes: null
    superseded_by: null
    ---

The legacy bullet form -- `# ADR 0001 — Title` with `- Status:` / `- Date:` as
prose -- still parses, flagged `legacy: true`. ADRs 0001-0003 used it and have
since been migrated; the reader stays because refusing an old-format ADR would
leave an accepted decision outside the index, which is the exact failure this
gem prevents.

Migrating an **accepted** ADR to frontmatter is possible because the digest
excludes preamble metadata: a legacy title heading and its Status / Date bullets
are metadata, not decision text. So the digest is identical before and after,
and that equality is the evidence that only metadata moved. Scoped to the
preamble -- a `- Date:` line inside a section is prose and is digested.

## Layout

    lib/mmg/adr/document.rb    parse a file into attributes (pure)
    lib/mmg/adr/projection.rb  attributes into N-Triples (pure)
    lib/mmg/adr/chain.rb       decision -> constraint -> code (pure)
    lib/mmg/adr/vocabulary.rb  the closed predicate set
    app/models/.../record.rb   the ledger row and its lifecycle invariants
    app/services/.../ingest.rb the boundary: read, upsert, publish

The pure half loads without Rails. `Record` and `Ingest` need ActiveRecord.

## Scope

This gem makes the state readable and the gaps visible. It does **not** block a
merge. Wiring a fitness function that fails CI on a new chain break is the next
step, and is deliberately not taken here -- see ADR 0014.

Apache-2.0.
