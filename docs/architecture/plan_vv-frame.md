---
owner: claude
---
# vv-frame — the shared trajectory, as a reader over an OKF bundle

**Built as `gems/vv-frame`.** Landed 2026-09-19 in `d7634b4`, flattened into
`gems/` by `3e3874f`. Private, **reader only**: no rubygems, no runtime
dependencies, no Rails, no ActiveRecord, no HTTP, no store.

Gate: `spec/refusals_spec.rb` — R1 and R2 are enforced by the **absence of a
method**, not by a validation, and are planted. `Vv::Frame.validate(bundle)`
gates the bundle itself; a bundle that fails is not served.

**This file documents what was built.** Its first revision (`7a13465`) proposed a
different design before checking what the eight unpushed commits contained, and
was wrong on both of its central choices. §8 records that, because the refusals
it violated are the load-bearing part of the gem.

---

## 1. What it is

A reader that serves one frame document and its 73 architecture-decision
concepts to the four parties who have to stay on the same path: development-time
agents writing code, production-time agents running in the pod, developers, and
users.

It is not a second ADR store and not a lifecycle authority. It never opens
`magentic-stack/docs/adr/` — zero occurrences of that literal in its 10 Ruby
files. It reads its own Open Knowledge Format bundle under `docs/`.

## 2. The bundle

`docs/` is OKF: one frame concept with its sections, and one concept file per
architecture decision. A concept is **not a copy** of the ADR. It carries
`okf_version`, a `resource:` and `sources:` pointing back at the real file in
magentic-stack, a `description`, `tags`, and a `frame:` block:

    frame:
      layer: repo
      phase: extract
      freezes_at_rung: 4
      evidence: gold
      instrument: refusal

Both link directions — decision grounds section, section grounded by decision —
are generated from a single edge table, so they cannot disagree.

## 3. What it answers

    res = Vv::Frame.load!("docs")     # load + gate
    b   = res.fetch(:bundle)

    b.for_path("gems/rails-osi-level-8/...")  # decisions governing a path,
                                              # most specific first
    d = b.decision("0052").fetch(:decision)
    d.placement.to_h   # {layer:, phase:, rung:, evidence:, instrument:}
    d.gates            # the checkers that enforce it
    d.grounds          # frame sections it grounds, with the reason
    d.body             # the decision's text, VERBATIM
    b.ledger           # the futures gauge: enforced / unenforced / ungated / total
    b.findings         # every placement that disagrees with itself

`findings` is a list an author acts on, never a verdict — the same posture
`check_enforced_by` takes toward an unenforced ADR.

## 4. Placement is declared, mirrored, and validated

The four axes are **declared** in each concept's `frame:` block, not derived from
the ADR's other fields. That is the stronger choice: a derived placement changes
silently whenever an unrelated field changes, and no one is accountable for the
new answer. Declared placement is wrong loudly, and `findings` is where it says
so.

Evidence gates rung climb. Layer and rung are the same ordinal. A placement that
violates either is a finding.

## 5. Two refusals, enforced by absence

| | forbidden | why |
|---|---|---|
| R1 | summarisation | Nothing rewrites, condenses or paraphrases a decision. Text is served verbatim or by section; a budget that cannot fit a section **drops it by name**. Compaction replaces the turns that happened with an inference and keeps the name. |
| R2 | ranking | Order is path specificity then id — both structural. The column is the affordance. |

Enforced by there being no method to call. `spec/refusals_spec.rb` asserts no
object in the gem answers to a summarising or scoring name, and that the source
carries no such method.

## 6. The smart-zone argument, checked rather than asserted

The smart part of a context window is ~100K tokens however large the window is,
and attention is U-shaped — what the middle loses first is constraints. Source
states what a system does, almost never what it may not do. The decisions do.

Packed as concepts they measure an estimated token count that fits inside the
smart zone with room to work. `ContextPack` is where that is **checked**, not
claimed, and where a budget too small to hold a section drops it by name rather
than shrinking it.

## 7. Where mmg-adr stands

Unchanged, and it stays that way. `mmg-adr` owns parse, the
proposed -> accepted -> superseded lifecycle, the AR ledger, the grounded graph
projection, and `body_digest` drift detection over `docs/adr/`. Its README fixes
the truth: *"The file stays the source of truth; the row is a projection."*

There is no duplication to reconcile, because the two gems never touch the same
bytes. `mmg-adr` reads `docs/adr/` and writes rows. `vv-frame` reads its OKF
bundle and writes nothing. The bundle's `sources:` is the only link, and it
points one way.

## 8. What the first revision of this file got wrong

Recorded because the errors are instructive about the design, not merely about
the author.

- **It forbade per-ADR files under the gem** as "a second copy." The 73
  concept files are not copies; they are OKF nodes carrying placement and edges,
  with `resource:` pointing at the original. The refusal would have banned the
  design.
- **It proposed deriving placement** from `paths:`/`enforced_by`. The built
  answer declares it. Derivation looks cheaper and is worse: it reclassifies a
  decision silently when an unrelated field moves.
- **It proposed a Tier-0 one-line-per-ADR surface.** That is exactly what R1
  refuses. The real answer to a budget is `ContextPack` dropping whole sections
  by name, so the reader knows what is missing.

The method error was writing a plan from four words and a directory listing while
eight commits titled `vv-frame: the frame and its decisions, as data an agent can
read` sat unpushed in the same tree.
