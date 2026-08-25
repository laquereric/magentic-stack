# PLAN — vv-slo, mmg-effect-plane and vv-docker-swap into magentic-stack

Status: **plan + preliminary POC design.** Nothing imported yet.

## Why these three together

They were built separately and they are not three features. They are three
consecutive answers to one question — *may this version become the live one?*

```
  vv-docker-swap        mmg-effect-plane           vv-slo
  ──────────────        ────────────────           ──────
  what gets built   →   what is materialized   →   what may go live
  (parent digest,       (which materialization      (the objective the
   per-service           is ACTIVE, and what          candidate must meet
   deltas)               rollback means)              to be activated)
```

A release today can say *what* shipped. It cannot say, in machine-readable form,
that the thing that shipped was the thing that was built, that its predecessor is
still activatable, or that it met a stated reliability bar before it took over.
These three close that, in that order.

**The load-bearing claim:** each hands the next a checkable artifact, so the chain
is auditable at every joint rather than only at the end. If that turns out to be
false — if the joints need glue code that invents facts — the integration is
wrong and should stop at whichever gem stands on its own.

## Where each one lands, under ADR 0001

ADR 0001 makes ownership legible from the path: `grammar/ gems/ runtimes/`
are OWN IT, `apps/ plugins/` are OFFICIAL, `upstreams/` is FOLLOW THEM. All three
are ours, so all three are OWN IT and subtree-imported per ADR 0002.

| gem | lands at | why there |
|---|---|---|
| `vv-docker-swap` | `tooling/docker-swap` | It is build discipline with a **checkable invariant** (`SharingInvariant`, `Expectations`). `tooling/` already holds the enforcement machinery — attestation, boundary, governance, pins, shacl — and this joins them. |
| `mmg-effect-plane` | `runtimes/effect-plane` | It is runtime truth: which materialization is live. `runtimes/` holds what runs (`graph`, `mind-pod`, `switch`); this holds the record of which build of them is active. |
| `vv-slo` | `tooling/slo` | It **is** a gate — the gem's own module is called `BudgetGate`. It belongs with the other release gates, and it earns a workflow beside them. |

The alternative placement worth naming: `vv-slo` could sit in `gems/` on the
grounds that an SLO is a contract, not a tool. It is a contract, but the thing we
want from it here is enforcement, and putting a gate anywhere but `tooling/` means
the next person looking for "what can block a release" has to know to look in two
places. Revisit if the SLO starts being consumed by products rather than by CI.

## What each gem actually provides

Read from the source, not from the READMEs:

**`vv-docker-swap`** — `Strategy`, `BuildRules`, `SharingInvariant`, `Accounting`,
`Expectations`. Its `Accounting` already proves the point that motivates it: naive
image-size summing overstates by **7.35x** for ten children on one parent, because
Docker stores a layer once per host regardless of how many images reference it.

**`mmg-effect-plane`** — `Vocabulary`, `Placement`, `Classifier`, `Snapshot`,
`Fork`, `Reference`. Plane C: rollback is legitimate **only** as fork-and-activate,
never as rewind. `docker commit` is explicitly not admissible as a materialization.

**`vv-slo`** — `Objective`, `BurnRate`, `BudgetGate`, `ObservabilityContract`,
`Runbook`. The premise the gem states: an agent implements exactly the spec it was
given, so an unwritten reliability requirement produces a service that does not
have it.

## Preliminary POC design

**One deploy, all three joints, one artifact.**

The POC is not "import three gems and run their specs" — that proves they still
pass, not that they compose. It is a single pass over an existing pod that
produces a record no one of them could produce alone.

### Target

`runtimes/mind-pod` — already subtree-imported, already has a Gate 1 Part C
runtime test, and is a real multi-container pod. No new infrastructure to prove a
chain that is about infrastructure.

### The pass

```
  1. PLAN THE IMAGES          vv-docker-swap
     Strategy over the pod's services -> one common parent + per-service deltas.
     SharingInvariant checks the plan is actually shareable.
     Accounting reports true cost vs naive sum.
     OUT: parent digest, child digests, an expectations set.

  2. MATERIALIZE              mmg-effect-plane
     Classifier admits (or refuses) each built image as a materialization.
     Snapshot records it; Placement says where it lands.
     Reference names the CURRENT active one -- the predecessor stays activatable.
     OUT: a candidate materialization, not yet active.

  3. GATE                     vv-slo
     Objective states the bar. ObservabilityContract states what must be
     measurable for the bar to be checkable at all.
     BudgetGate decides: may this candidate be activated?
     OUT: a verdict, with the objective it was measured against.

  4. ACTIVATE, OR DO NOT      mmg-effect-plane
     Fork-and-activate on pass. On fail the candidate simply never becomes
     the Reference -- nothing is rewound, because nothing was overwritten.
```

### The artifact

One JSON-LD record per pass, carrying: the parent digest, each child digest, the
materialization id, the predecessor it would replace, the objective, the burn-rate
reading, and the verdict. That is the **Release Packet** entry the platform work
already wants a spine for — this makes one concrete instead of designing it in
the abstract.

### Deliverables

| # | thing | proves |
|---|---|---|
| 1 | `bin/poc-deploy-chain` | the three compose over a real pod |
| 2 | `docs/plans/poc-deploy-chain.md` — the record's shape | the artifact is legible |
| 3 | `.github/workflows/slo-gate.yml` | the gate can actually block |
| 4 | a **deliberately failing** run | the gate blocks when it should |

Deliverable 4 is the one that matters. A gate that has only ever passed is not
known to be a gate.

## Sequencing

**Phase 0 — import.** Three subtree imports, `Gemfile` path-gems, specs green in
CI, `docs/SOURCE_STATUS.md` rows added. No behaviour change. Independently
valuable and independently revertible.

**Phase 1 — docker-swap over mind-pod.** Run `Strategy` against the pod's real
Dockerfiles. Report the accounting. **Change nothing.** The output is a claim
about what the images could be, and it should be read before it is acted on.

**Phase 2 — effect-plane records the current state.** Snapshot what is live now,
without changing it. This is the phase that most likely surfaces a mismatch
between the model and the deployment as it actually exists, which is worth finding
before anything depends on it.

**Phase 3 — the SLO, written down.** One objective for one pod. The first honest
version will be embarrassing in its modesty; that is correct. An objective nobody
will defend at 3am is not an objective.

**Phase 4 — join them.** `bin/poc-deploy-chain`, then the failing run.

Phases 1–3 are independent and can run in any order or in parallel. Only phase 4
needs all three.

## Risks, and the honest ones first

- **The chain may not close.** Step 2 needs step 1's digests to be the *same*
  digests that end up materialized. If the build path in magentic-stack does not
  surface digests where effect-plane can read them, the joint needs glue that
  invents facts — and glue that invents facts is exactly what the effect plane
  exists to prevent. **Check this in phase 1, before phase 2.**
- **`deploy/` is an empty scaffold.** These three describe a deploy discipline for
  a directory that currently holds a README. Either the POC drives the Hostinger
  rr-todo pods (real, already running) or it drives mind-pod locally. It should
  not pretend `deploy/` is a thing it is not.
- **An SLO with no telemetry is a wish.** `ObservabilityContract` exists precisely
  to make that failure loud, and phase 3 should expect to be blocked by it rather
  than route around it.
- **Three imports at once is three ways to break CI.** Phase 0 lands them one at a
  time, each green before the next.

## Open questions

- **Is `tooling/` the right home for two of the three?** It currently holds gate
  machinery, not libraries. If these are the first libraries there, that is a
  small precedent worth setting deliberately.
- **Does the Release Packet spine already have a shape** these should conform to,
  or does this POC define it? If the former, the record above must be reconciled
  rather than invented.
- **Which pod is the real target** — mind-pod (local, safe, already in CI) or the
  rr-todo pods (real, remote, actually deployed)? The POC is more convincing on
  the latter and much easier to iterate on the former.
