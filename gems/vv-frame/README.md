# vv-frame

Private gem. **Reader only.** The shared trajectory: the frame, its decisions,
and a budgeted load for the smart zone.

Not on rubygems.org. No runtime dependencies. No Rails, no ActiveRecord, no
HTTP, no store. It reads an Open Knowledge Format bundle — one frame document
and its architecture-decision concepts — and serves it to the four parties that
have to stay on the same path: **development-time agents** writing code,
**production-time agents** running in the pod, **developers**, and **users**.

Frame: [`FRAME.md`](FRAME.md). Bundle: [`docs/`](docs/).

## Why a reader at all

The smart part of a context window is roughly 100K tokens however large the
window is; attention is U-shaped, and what the middle loses first is
constraints. A codebase does not fit and would not carry them anyway — source
states what a system does, almost never what it may not do.

The decisions do. Seventy-three of them, packed as concepts, measure **~47,000
estimated tokens**: an entire substrate's constraint set inside the smart zone,
with room left to work. That is the whole argument for this gem, and
`ContextPack` is where it is checked rather than asserted.

## What it answers

```ruby
require "vv-frame"

res = Vv::Frame.load!("docs")          # load + gate; a bundle that fails is not served
b   = res.fetch(:bundle)

b.for_path("gems/rails-osi-level-8/lib/rails_osi_level_8/profile9")
# => [Decision, ...]  the decisions that govern that path, most specific first

d = b.decision("0052").fetch(:decision)
d.placement.to_h    # {layer: "gems", phase: "extract", rung: 3, evidence: "gold", instrument: "refusal"}
d.gates             # ["tooling/osi/check_admission_status_absent.py", ...]
d.grounds           # the frame sections it grounds, with the reason given
d.body              # the decision's text, verbatim

b.ledger            # {enforced: 66, unenforced: 11, ungated: 3, total: 73}  the futures gauge
b.findings          # every placement that disagrees with itself
Vv::Frame.validate(b)
```

## Trajectory — the object four parties share

Aim and receiver from the slice; constraints and gates from the decision tree;
placement from the frame. Loadable in one pass, re-loadable after a reset —
which is the whole specification.

```ruby
stakeholder = Vv::Frame::Slice.new(
  key: "read-own-record", aim: "A township can read its own record",
  receiver: "Township supervisor", receiver_kind: "stakeholder",
  outward_signal: { metric: "no re-contact", delay: "P7D" })

developer = Vv::Frame::Slice.new(
  key: "grounding-seam", aim: "The seam refuses an ungrounded publish",
  receiver: "Substrate developer", receiver_kind: "developer",
  outward_signal: { metric: "refusal observed", delay: "P1D" },
  for_slice: stakeholder)                       # orientation is transitive

t = Vv::Frame.trajectory(bundle: b, slice: developer,
                         path: "gems/rails-osi-level-8/lib",
                         party: :development_agent).fetch(:trajectory)

t.chain               # ["grounding-seam", "read-own-record"]
t.terminates_outside? # true — the aim leaves the system
t.gates               # what will catch me
t.findings            # slice findings + placement findings, as a list
t.to_markdown         # the loadable object
```

**T1 — the receiver predates the cut.** A receiver may not be anything the work
created: not the building team, not the agent, not the tooling, not the gate,
not a sibling slice, not the harness. `Slice#findings` returns
`receiver_did_not_predate_the_cut` for each, and a chain whose last receiver is
internal answers `aim_ends_inside_the_system`. That rule is what stops an agent
optimising the harness instead of the work.

A cycle refuses as `slices_are_one_whole` — named after what it means, not after
the mechanism that found it. Two slices receiving each other are one whole cut
in half.

**Both halves or neither.** Constraints without an aim build the wrong thing
correctly; an aim without constraints breaks the substrate on the way. A
production-time agent gets the same object as the agent that wrote the code —
same decisions, same gates — which is why a design-time decision stays legible
to the thing doing the work at runtime.

## ContextPack — a budgeted load for the sharp part of a window

```ruby
pack = Vv::Frame.pack(bundle: b, trajectory: t,
                      path: "gems/rails-osi-level-8/lib",
                      sections: %w[trajectory smart-context layers],
                      budget_tokens: Vv::Frame::ContextPack::SMART_ZONE_TOKENS
                     ).fetch(:pack)

pack.estimated_tokens   # ~8,600
pack.within_smart_zone? # true
pack.complete?          # false if anything did not fit
pack.to_markdown        # verbatim, structurally ordered
```

Two rules do the work:

- **Nothing is summarised.** A section either fits whole or does not travel. A
  constraint the reader never saw the original of is the defect this exists to
  prevent.
- **Nothing is dropped silently.** Everything the budget could not carry is
  named *inside the document* — kind, id, title, estimated size, and
  `budget_exhausted` — under `## Omitted from this pack`, led by
  `This context is **partial**`. A pack that hides its omissions reads as
  complete, which is worse than one that is obviously short.

Order is structural and therefore stable: trajectory, then named frame sections
in document order, then decisions by path specificity and id.

## The boundary never raises

Every call answers `{ ok: true, … }` or `{ ok: false, reason:, because: }`.
`Dry::Monads` is not a dependency and is not wanted.

| reason | means |
|---|---|
| `bundle_missing` | the root is not a directory |
| `frame_missing` | no `frame.md` at the root |
| `frontmatter_invalid` | a document's YAML does not parse — named, not skipped |
| `unknown_decision` | no decision carries that id |
| `bundle_invalid` | `load!` gated it; `because` carries the errors |

## Two refusals (load-bearing)

Enforced by the **absence of a method**, and planted in `spec/refusals_spec.rb`.

| | Forbidden | Grounding |
|---|---|---|
| R1 | summarisation | Nothing rewrites, condenses or paraphrases a decision. Text is served verbatim or by section, and a budget that cannot fit a section drops it by name. Compaction is a mutated observation: it replaces the turns that happened with an inference and keeps the name. |
| R2 | ranking | Order is by path specificity then id, both structural. No relevance score, no `priority`/`rank`/`position` field. The column is the affordance: if one existed, selection would quietly become judgement. |

`REFUSED_OPERATIONS` is the closed list, and the spec fails if any object or any
`def` in `lib/` matches it. That is why `Placement` says `evidence_ordinal` and
not `evidence_rank`: an ordinal in a closed set is a structural fact, and the
gem declines the vocabulary of scoring so nothing can drift into it.

A token count is named `estimated_tokens`, never `tokens`. A fabricated
magnitude gets acted on; a documented estimate does not.

## Placement

A decision's position on four axes, read from its OKF frontmatter:

```yaml
frame:
  layer: gems         # where the change lands
  phase: extract      # which 3X phase the work is in
  freezes_at_rung: 3  # what it costs to reverse, and who bears it
  evidence: gold      # what licenses the commitment
  instrument: refusal # pin | rung | refusal | operate | ledger
```

`Placement#findings` returns every way those axes disagree — a list an author
acts on, never a verdict. The rules are the frame's:

- **Evidence gates rung climb.** Rung 0–1 is Bronze work; rung 2 wants Silver;
  rung 3–4 wants Gold. You may not freeze above what your evidence supports.
- **Layer and rung are the same ordinal.** An overlay freezing at rung 4 is
  flagged, and the resolution is *move the work, not the gate*.
- **Each layer has a home phase.** Explore work in `grammar/` is a finding.

## The validator is the bundle's gate

`Vv::Frame::Validator` checks dangling anchors, dangling decisions, **link
symmetry in both directions**, orphans, and unknown placements.

Symmetry is the load-bearing check. A decision that claims a frame section the
section does not list back is a contract maintained beside the code, which is a
memo. Every check is planted: the bundle is broken in the way the check names
and the check is proven to fail. *A checker that has never been planted is not a
gate.*

## Develop

```
bundle install
bundle exec rspec
```

The suite runs against fixtures built in a tempdir, and — when `docs/` is
present — against the real bundle beside it as well.
