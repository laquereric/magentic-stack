# Gap analysis

Measured 2026-08-31 at `8e2248a`. Target doctrine: ADR 0046 (vault separate),
0047 + amendments (three languages, container boundaries, one Rails app with
many ROLEs), 0048 (MIND serves a CPCP seam), 0049 (ROLE=shape from mounted
gems).

**Target: 10 containers, 4 images.** One Rails application run under seven
ROLEs, plus MIND (Python), SWITCH (Rust), and third-party oxigraph.

## 1. Containers

| # | Container | Image / language | Today | Gap | State |
|---:|---|---|---|---|---|
| 1 | `back` | Rails, shared | `ROLE=back`, sole domain writer, draws `/_cpcp` | shares `mind-data` with `backjob`, so sole-writer is not physically enforced | partly done |
| 2 | `backjob` | Rails, shared | `ROLE=backjob`, CPCP completion now works | mounts `mind-data`; `bin/backjob:37 Reconciliation.create!` writes domain rows directly | **owner decision** |
| 3 | `front` | Rails, shared | `ROLE=front`, route-gated off `/_cpcp` | was serving the write seam until `0a7d67f`; historical exposure not established | done / 1 question |
| 4 | `vault` | Rails, shared | `ROLE=vault` landed `968d3cd` | no caller wired yet; nothing consumes it | ready |
| 5 | `config-admin` | Rails, shared | does not exist | build as `ROLE=config`; becomes the **only** published port | **next** |
| 6 | `shape` | Rails, shared | does not exist | no shape HTTP surface exists anywhere; must be designed against ADR 0045's list | open |
| 7 | `project-graph` | Rails, shared | does not exist | projection code is Rails-side but `Storable` is unwired, so `graph` comes up empty | open |
| 8 | `mind` | Python, own | CPCP **client** only: `CMD ["harness.py"]`, no `EXPOSE`, no inbound surface | must serve `/_cpcp/rpc` and map NOOA push/pull | **blocked** (row 11) |
| 9 | `switch` | Rust, own | **Node**: 17 `.mjs`, `server.mjs` 350 lines, two ports in one process | full rewrite; must become RES bus **and** LLM plane | **blocked** (rows 12, 13) |
| 10 | `graph` | oxigraph, third-party | running, digest-pinned, **empty** | third-party image: exempt from the language rule, but the exemption is assumed rather than written | open |

## 2. Cross-cutting gaps

| # | Gap | Measured today | Blocks | State |
|---:|---|---|---|---|
| 11 | **CPCP has no language-neutral specification** | `rails-cpcp` is a Rails engine; no schema, no protocol doc, no conformance suite. The contract IS the Ruby implementation | MIND's Python seam (row 8) | **prerequisite** |
| 12 | **No durable event repository** | zero hits for `event_store` / `EventStore` / `event_repository` across `gems/` and `runtimes/`; PERSIST absent from the converged list | the RES half of SWITCH (row 9) | **owner decision** |
| 13 | **Rust / upstream relationship undecided** | zero `.rs` files; `Cargo.toml` has `members = []`; `nemo-switchyard` is do-not-fork (ADR 0038) | SWITCH (row 9) | **owner decision** |
| 14 | **Two `/_cpcp` seams, MIND's authority unstated** | every existing statement says the seam is *the only write path*, written when there was one | reading "BACK is sole writer" literally | **owner decision** |
| 15 | **Route-gating is not CI-gated** | `routes.rb` gates by ROLE and `vault_spec.rb` covers it, but no checker and no workflow; nothing stops a mount outside the `case` | every future ROLE | **next** |
| 16 | `osi.example` is unresolvable | 11 shapes resolve under `https://osi.example/shapes/...` | becomes externally visible the moment `shape` SERVES rather than stores | open |
| 17 | Shape payload only partly migrated | 7 TTL in the two shape gems, **52 still in `osi-level-8-profiles`**; shape-arc step 10 unrun | whether `shape` serves the moved set or the whole catalogue | open |
| 18 | FRONT historical exposure | unknown whether any operation was ever admitted through FRONT's `/_cpcp` | nothing structural; a durable-state question | open |

## 3. Outside the language rule

| # | What | Count | Status |
|---:|---|---:|---|
| 19 | Python release gates under `tooling/` | 23 | **carve-out adopted**: "`tooling/` is Python until rewritten", not coupled to vault or SWITCH |
| 20 | Python validators in `gems/osi-level-8-profiles` | 4 | same carve-out |
| 21 | Shell: `bootstrap`, `build-baselines`, `docker-containers`, `prereq` | 4 | outside all three languages; neither allowed nor disallowed |
| 22 | CI workflows (YAML) | 11 | not covered; they are what **invoke** the Python gates |
| 23 | `runtimes/effect-plane` | 1 gem | no container assigned |
| 24 | `mmg-blob` / `vv-blob` | 2 gems | blob storage has no owner |

## 4. Browser carve-out (not violations)

| # | What | Why it is JS |
|---:|---|---|
| 25 | `gems/switchyard-offline` | Chrome MV3 extension + loopback listener; the one gem in the tree with **no gemspec** |
| 26 | `gems/vv-html-components` | web components (`dist/*.js`, `test/*.mjs`) |
| 27 | `rails-osi-level-8/data/osi-level-8/ux-host-layout.js` | browser asset |
| 28 | `config-admin`'s own UI, once it exists | runs in a browser |

## 5. Accepted costs

| # | Cost | Source |
|---:|---|---|
| 29 | Hot-patch granularity is **4 units, not 10** -- a `vault` fix rebuilds the image six containers run | ADR 0047 amendment 1 |
| 30 | ADR 0046 weakened: `vault` keeps its container (network, mount, allowlist, read-back asymmetry all intact) but **not** image isolation | ADR 0047 amendment 1 |
| 31 | Prose that is now false: `mind_agent.py:58` -- "There is no second socket, and there is no write path for you" | ADR 0048 |

## What is on the critical path

1. **Row 15** -- route-gate checker. Cheap, and every future ROLE depends on it.
2. **Row 5** -- `config-admin`, which finally gives `vault` a caller.
3. **Row 11** -- extract a CPCP contract + conformance suite. Blocks MIND entirely.
4. **Rows 12 and 13** -- both owner decisions, and together they block SWITCH.
5. **Row 2** -- the backjob writer boundary, still the only *live* correctness defect on this list.
