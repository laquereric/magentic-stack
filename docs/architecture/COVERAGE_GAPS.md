# Coverage gaps against ADR 0047 (as amended)

Measured 2026-08-30 at `e9ab2a1`. The question asked: given SWITCH = RES bus +
LLM plane (Rust), MIND (Python), and one Rails image behind vault /
config-admin / shape / front / back / backjob / project-graph -- **what is not
covered?**

Target: **10 containers, 4 images.**

## A. Decisions, not housekeeping

### A1. There is no durable event repository, and PERSIST is not in the list

`grep -rl 'event_store|EventStore|event_repository' gems runtimes --include=*.rb`
returns **nothing**. `rails_event_store` is not a dependency anywhere.

SWITCH is now the RES bus. `docs/reviews/2026-08-30d` held that the bus must not
own the durable event repository, and `2026-08-30c/g` assigned that to PERSIST.
PERSIST is absent from the converged list. So the durable event log is owned by
nobody, or silently by BACK's SQLite.

**This is the largest gap.** A bus without a repository is a delivery mechanism
with no history; the RES half of "SWITCH is the RES bus" is unimplementable
until this is answered.

### A2. `shape` as a container contradicts ADR 0045

ADR 0045 decided that `rails-cpcp` -- a Rails **engine mounted inside BACK** --
is the Stage 2 SHAPE container, and that `app-shacl-store` is the Stage 3
commercial surface. A separate `shape` **container** is a third answer.
Either 0045 is amended or `shape` means something narrower than it did there.

### A3. The Rust/upstream relationship is still unsettled

SWITCH becomes Rust. `upstreams/nemo-switchyard` is NVIDIA's Rust Switchyard
under the do-not-fork boundary of ADR 0038. We have **zero `.rs` files** and
`Cargo.toml` declares `members = []`. Whether we write ours, consume theirs
through a supported interface, or run both is not decided.

## B. Code with no container, and therefore no home in the language rule

| What | Count | Status |
|---|---|---|
| Python release gates under `tooling/` | 23 files | **open** -- carried over from ADR 0047; includes every gate we hardened this week |
| Python validators in `gems/osi-level-8-profiles` | 4 files | **open**, same question |
| Shell: `bootstrap`, `bin/build-baselines`, `bin/docker-containers`, `bin/prereq` | 4 files | outside all three languages; nothing says shell is disallowed, but nothing says it is allowed |
| CI workflows (`.github/workflows`) | 11 files | YAML; not covered, and they are what **invoke** the Python gates |
| `runtimes/effect-plane` | a Ruby gem | no container assigned; not in the converged list |
| `mmg-blob` / `vv-blob` | Ruby gems | no container; blob storage has no owner |

## C. Covered by the browser carve-out (not violations)

- `gems/switchyard-offline` -- Chrome MV3 extension + loopback listener; the one
  **gem in the tree with no gemspec**, JS only
- `gems/vv-html-components` -- web components, `dist/*.js` + `test/*.mjs`
- `gems/rails-osi-level-8/data/osi-level-8/ux-host-layout.js` -- browser asset
- the browser half of `config-admin`'s own UI, once it exists

## D. Covered but worth naming

- `graph` runs a **third-party** oxigraph image. It is a container in the pod
  that is not ours in any of the three languages. Exempt as a datastore, but the
  exemption should be explicit rather than assumed.
- `upstreams/nooa` and `upstreams/nemo-switchyard` are follow-them trees, not
  deployed by us (ADR 0038).
- `grammar/osi-level-8` is normative prose, not code.

## E. Consequence, already recorded in ADR 0047's amendment

Hot-patch granularity drops from **ten units to four**. A `vault` fix rebuilds
the image that six other containers run.

## F. Added after the "one Rails app, many ROLEs" clarification

### F1. ROLE does not gate the route table (PREREQUISITE, not a gap to defer)

`config/routes.rb` draws every route for every role; BACK and FRONT appear
there only as comments. The FRONT container therefore serves `/_cpcp`, and in
`app/extract/compose.yml` FRONT is published on host port 13000. "BACK is the
sole writer" holds by convention about which URL clients are given, not by
construction.

Until ROLE gates routing, every new ROLE container serves the whole
application, and ADR 0046's vault boundary cannot mean what it says.
See ADR 0047 amendment 2.

### F2. What ROLE gates today, for reference

| Gated by ROLE | Not gated by ROLE |
|---|---|
| `application.rb` role config | **the route table** |
| `mmg_graph.rb` initializer | |
| `osi_level_8.rb` initializer + CpcpAdapter install | |
| `session_projection.rb` initializer | |
| `rails_cpcp_session.rb` initializer | |
| `extract/entrypoint.sh` process dispatch | |

## G. Added after "MIND provides /_cpcp/rpc" (ADR 0048)

### G1. CPCP has no language-neutral specification -- PREREQUISITE

`gems/rails-cpcp` is a Rails engine. No schema, no protocol document, no
conformance suite. The contract IS the Ruby implementation. A Python seam in
MIND would be a second implementation of an unspecified protocol.

Needed before any Python is written: a written contract, plus a conformance
suite that both seams must pass. Check first whether `laquereric/json-rpc-ld`
(spec-only; CPCP is described as a conforming profile) is complete enough to
implement against -- **not established**.

### G2. Two seams; MIND's authority is unstated

The pod gains a second `/_cpcp/rpc`. Every existing statement of the invariant
says the seam is *the only write path*, written when there was one. Whether
MIND's seam is an adapter surface or a second authority is **undecided**, and
until it is decided "BACK is the sole writer" cannot be quoted literally.

### G3. MIND gains an inbound surface for the first time

Today: `CMD ["harness.py"]`, no `EXPOSE`, outbound stdlib `urllib` only, and
default-deny egress to BACK and SWITCH. Serving a seam changes MIND's threat
model. Pod-internal only, and who may call it is an allowlist decision of the
kind ADR 0046 made for `vault`.

### G4. Load-bearing prose that is now false

`runtimes/mind-pod/mind/mind_agent.py:58` -- "There is no second socket, and
there is no write path for you at [MIND]". Must be rewritten, not left to rot.
