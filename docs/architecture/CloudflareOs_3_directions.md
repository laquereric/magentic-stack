# Cloudflare OS and magentic-stack — three directions

**Design only. Nothing here is built.** No submodule, no adapter, no
`workerd` binary, no compose service, no gem, no `cfos.*` CPCP method.
`grep -ril cloudflare` over this repo's `.md`, `.rb`, `.yml`, `.yaml`
returns **zero hits** as of 2026-09-13. This file decides nothing; it
states what each direction would commit us to, so the owner picks a
position rather than drifting into one.

**Outcome so far.** The systematic comparison behind this file is
[`CloudflareOs_Contrast.md`](CloudflareOs_Contrast.md). One item from the
borrow list has been adopted: ADR
[0070](../adr/0070-never-persist-datasets-and-the-inverted-observer-seam.md)
takes the observer *seam* and inverts it — an observed dataset is never
persisted, and a viewer's own read is the authorization check, which
deletes the ledger rather than importing it. It closes open question 3
below and re-bases open question 6 as its blocking precondition.

Sources read: `magentic-market-ai/docs/research/cloudflare-os-rehost-process.md`
(drafted September 2026, against the August 2026 v2 release), and — since
the 2026-09-13 revision — **the Cloudflare OS repository itself** at
`/Users/ericlaquer/NoIcloud/cloudflare-os`, HEAD `08afe059`: `README.md`,
`CONTRIBUTING.md`, `REVIEW.md`, `docs/observers.md`,
`docs/public-server.md`, `plans/gatekeeper-kit.md`, `wrangler.jsonc`,
`packages/`. Companion in form:
[`IntegrateDuckDb_3_paths.md`](IntegrateDuckDb_3_paths.md).
Governing records:
ADR [0001](../adr/0001-ownership-boundary.md) (ownership boundary),
[0030](../adr/0030-adapters-boundary-is-enforced.md) (adapters sole path),
[0038](../adr/0038-magentic-stack-is-closed.md) (closed; upstreams pinned, never forked),
[0047](../adr/0047-three-languages-container-boundaries-own-images.md) (three languages, containers are the only boundary),
[0057](../adr/0057-three-kinds-of-state.md) (three kinds of state),
[0061](../adr/0061-switchyard-pre-alpha-pin-is-the-accepted-risk.md) (how an immature pin is contained),
[0063](../adr/0063-application-overlays-consume-the-substrate.md) (an application is an overlay),
[0068](../adr/0068-a2a-internet-is-the-host-binding.md) (internet A2A is the host binding),
[0019](../adr/0019-switchyard-content-blind-router.md) (the router is content-blind and holds the credential).

---

## Provenance: verified first-hand

**Revised 2026-09-13.** The first draft of this file was written from the
rehost guide alone and said so. The repository has since been read
directly at `/Users/ericlaquer/NoIcloud/cloudflare-os`, HEAD `08afe059`
("Restricted data UI — share modal stays usable for restricted
workspaces", #308). License confirmed **Apache 2.0**. Five load-bearing
claims were checked:

| # | Claim | Verdict |
|---|---|---|
| 1 | Not seeking outside contributions; ~dozen-line PRs only | **CONFIRMED verbatim.** `CONTRIBUTING.md` and `README.md` §Contributing, identical text. |
| 2 | Self-host on `workerd` still **COMING SOON** | **CONFIRMED.** `README.md:196-200`, at this HEAD. |
| 3 | Facet / Dynamic Worker maturity is the runtime risk | **CONFIRMED and sharpened.** See C6 — the number is worse than "recent". |
| 4 | Isolate economics are why per-user instances work | **NOT CONFIRMED — the guide's inference, not Cloudflare's claim.** Corrected in direction 3. |
| 5 | Eleven Gatekeepers | **MOVED.** Twelve service gatekeepers plus five infrastructure ones, and a kit for writing more. |

Two findings the guide did not have, and which matter more than any of
the five:

- **Observer verification is built, not designed.** `docs/observers.md` is
  a complete mechanism with a committed API, a per-resource strategy
  table for every gatekeeper, and its own known gaps ledgered at their
  code sites. The guide called this the system's most novel claim and the
  one most worth testing yourself; it is considerably further along than
  the guide knew. This is the single most useful thing in the repository
  for us, and it is usable without taking a line of code.
- **The self-host identity story is largely solved**, and the guide's
  §6.1 — which it marked `[Unknown]` and "correctness-critical" — is
  answered by `docs/public-server.md`.

Where this file still says `[Inferred]` or `[Unknown]`, that marker is now
**ours**, not the guide's.

---

## What Cloudflare OS is, in this repo's vocabulary

This is the analysis the three directions rest on. Cloudflare OS is **not
a capability provider**. NOOA gives us agents; Switchyard gives us
routing; both slot *under* `gems/adapters/` because they answer questions
the stack does not claim to answer itself. Cloudflare OS answers the
questions this repo exists to answer.

| Cloudflare OS construct | Magentic construct | Tier collision |
|---|---|---|
| Gatekeeper — wraps one external service, holds OAuth, narrows to one resource, logs every action | P6 `AuthorizationDecision` / `CredentialRef` / `Revocation` (ADR 0026) + `gems/adapters/` + vault (ADR 0046) | **OWN IT** |
| Capability-based introduction; default-deny until introduced | P2 reference-passing (ADR 0023) + base-profile default-deny | **OWN IT** |
| Observation tracking that follows derived artifacts across sharing — **built**: `addObserver` / `excludeObservers`, re-verified every open | P5 biography and provenance (ADR 0025) + P7 observation and outcome (ADR 0027) — both `proposed` | **OWN IT** |
| Deferred approval by simulation — agent proceeds on simulated results, human approves in bulk later | **nothing.** Refuse-don't-raise stops the agent instead | **gap on our side** |
| Egress disabled in gadget servers; access only via bindings | ADR 0019 content-blind router, allowlisted TLS-only egress, agent holds no credential | **OWN IT** |
| Durable Object per workspace; per-facet SQLite | ADR 0057 three kinds of state; closed sqlite paths + writer-sets in `store_bindings.json`; persist owns placement (ADR 0051) | **OWN IT** |
| Cap'n Web object-capability RPC | CPCP JSON-RPC-LD (`/_cpcp/rpc`), A2A over NATS (ADR 0066/0067), A2A internet (ADR 0068) | **OWN IT** |
| AI Gateway — model routing, spend caps, per-user attribution | SWITCH (ADR 0019, 0050) | **OWN IT** |
| Cloudflare Access — who may enter at all | not owned here; an OIDC gate in front of the pod | open either way |
| Gadget — per-user app instance in an isolate, sandboxed iframe client | ADR 0063 overlay: a Rails engine gem in its own repo, thin image `FROM rails-base` | **OWN IT, different answer** |
| `workerd` — the runtime that makes isolate-per-gadget economics work | containers (ADR 0047); there is no isolate tier | **OWN IT, no analogue** |
| `pi-agent-core` (Pi) — one API across providers | NOOA under an adapter; SWITCH for completions | **FOLLOW, already occupied** |

**The finding.** Nine of thirteen rows land in the OWN IT tier. Cloudflare
OS is a *rival answer* to the stack's own thesis — governed agent access
to enterprise resources through capability-mediated introductions with an
audit trail — arriving with a working product where the stack has
`proposed` profiles and unbuilt containers. It is not an upstream. The
`upstreams/` tier is for things we follow because we do not claim them;
following something that occupies the contract layer is conceding the
contract, and no pin file records that.

That does not make it worthless to us. It makes the decision a
positioning decision, not an integration decision.

---

## The rehost guide's replace-list, scored against what we already own

The guide's §4 table is what a greenfield adopter must build after
leaving Cloudflare's network. Scored against this repo:

| Cloudflare managed service | Guide's replacement direction | What magentic already has | Ours? |
|---|---|---|---|
| Cloudflare Access | OIDC/SAML gate at ingress | nothing — the pod has no identity gate of its own | **no** |
| *(the guide was wrong to list this as work)* | — | Cloudflare OS **ships** self-host auth: built-in username/password, or `AUTH_GATEKEEPERS=cloudflare,google,github` sign-in keyed on verified email (`docs/public-server.md`) | n/a |
| AI Gateway | LiteLLM / Helicone / internal proxy | SWITCH: content-blind, credential-holding, allowlisted TLS-only egress, two-port split (ADR 0019) | **yes, live** |
| MCP Server Portals | self-hosted MCP gateway, or route through Gatekeepers | CPCP seam + `seam_authority.json` + `boundary_manifest.json`; every served method manifested | **yes, live** |
| Email Workers | SMTP ingest feeding the same handler | nothing | **no** |
| Containers | re-check upstream | twelve containers, four images, already the boundary model | **yes, live** |

And the guide's §5 control plane — the part it calls "the largest and
least-documented phase," the work you inherit when Cloudflare stops
running it for you:

| §5 responsibility | Magentic equivalent | State |
|---|---|---|
| Durable Object placement and routing | persist: placement authority over the closed store set, next-boot only, never live (ADR 0051, 0047 gap table) | **live container, measured 2026-09-03** |
| Persistence, backup, format **[Unknown]** in the guide | `store_bindings.json` closed paths + writer-sets, gated; journal is the only admission truth (ADR 0052) | **live and gated** |
| Process supervision, rolling upgrades | no live swap of a running process's store; restart applies (charter, ROW41 S1) | **decided** |
| Scaling **[Unknown]** in the guide | not answered here either | **open both ways** |
| Observability | LOG as thirteenth container — ADR 0058, **decided-unbuilt** | **decided, not built** |

**So the sharpest fact in this document:** the stack already owns most of
what a Cloudflare OS rehost requires you to build. The marginal value of
adopting is therefore concentrated in the two things the guide says cost
the most to take — the isolate/facet gadget economics (§10: reimplementing
them "approximately, you keep the interface and lose the assurance") and
the product UI. We would pay the highest-priced part of the bill to
acquire the one part we do not have, and re-buy the parts we already own.

That asymmetry is an argument, not a verdict. It is the argument direction
3 has to beat.

---

## What is actually there, on our side (so this is not a wish)

Measured 2026-09-13 against this tree.

| Thing | State |
|---|---|
| Any Cloudflare reference in the repo | **none.** Zero hits. |
| `workerd` / `wrangler` / Node runtime for a gadget tier | **none.** |
| `apps/`, `plugins/`, `deploy/`, `integration-tests/` | **do not exist.** The README maps them; the tree has `bin grammar gems runtimes tooling upstreams docs evidence`. |
| Containers | **twelve**, four images (`ContainerTopology.md`, ADR 0047 amendment). `nats` landed 2026-09-08. |
| Languages | Python (MIND), Rust (SWITCH — declared; SWITCH is **Node** today, 17 `.mjs`, the largest gap in 0047), Ruby-in-Rails-form (everything else). Browser JS is a named carve-out. |
| P6 authorization evidence | **proposed, no implementation.** Manus-drafted. |
| P7 observation and outcome | **proposed, no implementation.** |
| Identity gate | **none.** |
| Published base images | `rails-base`, `switch`, `mind` at `ghcr.io/laquereric/magentic-stack`, `sha-<40-char>`, no `:latest` |
| Overlay precedent | `app-oriented-translation` builds `Dockerfile.thin` `FROM mind-pod-rails-base`, "and nothing else" |
| Upstream pins | 5 submodules. NOOA and Switchyard are `shallow = true`. Switchyard is pre-alpha, 64 commits past an rc, pin gated by re-review record (ADR 0061). |

Two of these matter disproportionately. **P6 and P7 are `proposed`** — the
two profiles that collide most directly with Gatekeepers and observation
tracking are the two with no implementation. And **SWITCH is Node while
0047 says Rust** — the language rule already carries an unclosed gap, so
"one more language" is not a fresh cost, it is a second unpaid one.

---

## The collisions, named rather than papered over

Each direction pays some subset of these. Naming them here means no
direction gets to be quietly cheaper than it is.

**C1 — ADR 0047, languages.** Cloudflare OS is TypeScript/JavaScript on
`workerd`. The three permitted languages are Python (MIND), Rust
(SWITCH), Ruby-in-Rails-form (everything else). The browser carve-out
does not reach a server runtime. A fourth language is an amendment to a
doctrine whose stated tie-breaker is *minimum developer cognitive load,
deliberately not hedged*.

**C2 — ADR 0047, boundaries are containers exclusively.** "We do not
express an architectural boundary as a role, a thread, a supervised
process group, or a module convention." Cloudflare OS's boundaries are
isolates and Durable Object facets — precisely a supervised in-process
boundary. This is the deeper collision, and it is not fixable by adding a
language. Taking the gadget model means conceding that containers are not
the only boundary, which is the load-bearing simplification of the whole
container topology.

**C3 — ADR 0038 + 0061, pinned never forked.** The guide's §9 is explicit:
rehosting changes will not be upstreamed; you maintain the delta forever;
keep it small by preferring configuration over edits. ADR 0061's
machinery — `accepted_pin`, `pinned_revision`, a `reviews[]` record with
`looked_at` and `because`, gitlink equality, working-tree drift as a
distinct failure — contains a **pin**. It has nothing to say about a
permanent delta, because the repo has never accepted one. "Do not edit
files under `upstreams/...`; for a submodule that *is* a pin move."

**C4 — two placement authorities.** persist owns placement against a
closed store set, next-boot, never live. Durable Object placement is the
runtime's, and the guide marks the on-disk format **[Unknown]** —
including whether it tolerates snapshotting while live. Two authorities
deciding where state lives is the shape ADR 0051 exists to prevent.

**C5 — two RPC seams.** Cap'n Web is an object-capability RPC; CPCP is
JSON-RPC-LD with dual-signal HTTP mapping, a manifested method set, and
"refuse, don't raise." ADR 0068 already refused to mix A2A `message/send`
onto `/_cpcp/rpc` because it would break CPCP clients. A third frame gets
the same question and does not obviously get a different answer.

**C6 — the maturity stack, now measured.** The guide flagged facet and
Dynamic Worker parity as `[Unknown]` — "confirm each is present in your
pinned `workerd` build rather than assuming parity." Read directly, the
exposure is sharper than that:

- Every `wrangler.jsonc` in the repo declares
  **`compatibility_date: 2026-09-04`** — *nine days* before this revision
  — plus the `enable_ctx_exports` compatibility flag. A self-hosted
  `workerd` must be new enough to satisfy a compatibility date that is
  effectively current.
- The README states that "Dynamic Workers, Facets, and several other
  features were added to the runtime **specifically to support Cloudflare
  OS**, with more to come." The runtime features are co-evolving with the
  product, by design.

So the pin is not "recent" — it is a moving target on both sides at once,
and the product's own compatibility floor advances with it. Compare
ADR 0061: Switchyard's pin is pre-alpha but it is *a commit*, and the gate
holds it still. Here, holding still is what breaks. We already carry one
pre-alpha pin as an accepted, gated, re-reviewed risk. Carrying a second
whose floor moves weekly, and which would be a fork rather than a pin, is
a different class of exposure.

---

## Three directions

**These are positions, not a ladder.** Unlike the DuckDB paths, direction
*n* is not a prerequisite for *n+1*, and they are not all shippable
slices of one thing. 1 and 2 are compatible in sequence; 3 supersedes
both and is close to irreversible, because it amends 0047 and accepts a
fork.

```
  Direction 1  Ignore it            ← costs nothing, learns nothing, dated by choice
  Direction 2  Make it optional     ← three readings; two are already free
  Direction 3  Bake it in           ← amends 0047, accepts a permanent fork
```

---

### Direction 1 — Ignore Cloudflare OS

**The position.** Cloudflare OS is a competitor in the same conceptual
territory, not a dependency and not an upstream. The stack takes nothing,
pins nothing, names nothing. No submodule, no adapter, no ADR, no slot.

**What it costs.** Nothing to build. One thing to write down, because an
unrecorded non-decision decays into an assumption: this file, or a
one-paragraph ADR with `status: accepted` saying the stack does not
consume Cloudflare OS and why. An unrecorded "we ignored it" cannot be
re-examined on evidence, and is indistinguishable from never having
looked.

**What it does not cost.** Credibility. The replace-list table above is
the defensible answer to "why not just use Cloudflare OS": SWITCH already
does what AI Gateway does, the CPCP seam already does what MCP Portals do,
containers already are the boundary, persist already owns placement. The
stack is not behind on the rehost path — it is on a different path that
happens to have already built the same control plane.

**What it forfeits.**

1. **A working proof of the thesis.** Cloudflare OS ships Gatekeepers for
   eleven named third parties, each with a setup README. P6 is `proposed`.
   Whatever else is true, someone shipped the governed-credential pattern
   at scale and we can no longer claim the idea is unproven — only that
   our shape of it is unbuilt.
2. **The free conformance suite.** The guide's §7 is a five-item security
   validation list written by someone who had to verify these guarantees
   without inheriting them. It maps almost item-for-item onto the stack's
   own claims. Ignoring the product is cheap; ignoring that list is
   throwing away a test plan someone else wrote.
3. **Two ideas the stack does not have.** Named in "borrow regardless"
   below.

**Refusal codes this direction implies:** none. There is nothing to
refuse, which is the point.

**Claim this direction earns:** "we evaluated it, we own the overlapping
layer, here is the row-by-row comparison." That is a stronger position
than adoption for a substrate whose whole thesis is owning the contract.

**Claim it does not earn:** "our authorization evidence and observation
tracking work." Those are `proposed`. Direction 1 must not be allowed to
mean the profiles are fine as they are.

---

### Direction 2 — Make it optional

**"Optional" is ambiguous, and the ambiguity is where the decision
lives.** Three readings, with very different costs. Two of them require
no substrate change at all — which is the non-obvious result of this
whole document.

#### 2a — Cloudflare OS as a *caller* of the pod

A Cloudflare OS deployment speaks CPCP / A2A **to** the pod. ADR 0068
already built this surface: `GET /.well-known/agent-card.json`, `POST
/_a2a/rpc`, `preferredTransport: HTTP`, JSON-LD Context / Effect
DataParts, served when `HTTP_BIND=0.0.0.0` on extract BACK and 404'd on
loopback.

**Substrate cost: zero.** Nothing is imported, so ADR 0030 is not even
engaged — the adapters boundary governs code that *reaches into*
`upstreams/`, and here the substrate is the server. Nothing is pinned, no
language is added, no boundary is conceded. A Gatekeeper or gadget that
calls `/_a2a/rpc` is just an A2A client, and the Card does not know what
wrote it.

**What it requires:** that the Card and the RPC surface are actually
reachable and actually conformant, which `check_a2a.py` and
`plant_a2a.py` already gate. Plus the identity gate the stack does not
have — the guide's §6.1, which it marks **[Unknown]** and
"correctness-critical; test it adversarially." That gap is ours
regardless of direction.

**This is the recommended reading of "optional."**

#### 2b — Cloudflare OS as a capability provider behind an adapter

The pod calls *into* a Cloudflare OS deployment — to run a gadget, or to
use one of the eleven shipped Gatekeepers rather than writing our own
adapter for that third party.

**Substrate cost: real.** A sixth submodule under `upstreams/`. A widened
`gems/adapters/` with a pin matrix and integration tests (ADR 0030). A
pin.json with an `accepted_pin` and the 0061 re-review shape. And then
C6: the pin is early-access, on a v2 rewrite, with self-host tooling
COMING SOON, and — unlike Switchyard — **useful consumption may require
the permanent delta of §9**, at which point it is not a pin and 0038
refuses it.

The narrow version that survives 0038: pin it, call it over HTTP/CPCP,
edit nothing. If the thing we want from it cannot be had without editing
`workshop-backend`, the answer is no, and the pin gate should be the
place that says so.

**What the count actually is, read directly.** Not eleven. Twelve
*service* gatekeepers — `cloudflare confluence email github google
homeassistant linear notion slack spotify supabase zoominfo` (Linear
postdates the README's own setup list) — plus five *infrastructure* ones:
`context`, `mcp`, `mcp-portal`, `scheduler`, and `kit`.

Two of those change the 2b calculation:

- **`gatekeeper-kit`** is a real package, Layer 1 landed, with a
  conformance suite and a `write-gatekeeper` agent skill under
  `.agents/skills/`. Its stated purpose is that a new gatekeeper is "a
  TypeScript spec plus service-specific sessions, instead of ~400–500
  lines of hand-copied plumbing." So the marginal cost of *writing* a
  gatekeeper for an internal system is falling on their side.
- **Cloudflare intends to decouple them.** README:79 — "we envision
  Gatekeeper services being deployed and maintained independently from OS
  instances, but the details have yet to be worked out." That is
  precisely the shape that would make 2b clean: a Gatekeeper we could
  pin and call without hosting the OS. It does not exist yet, and
  "details have yet to be worked out" is not something to plan against.

**Honest assessment:** 2b buys twelve OAuth integrations we would
otherwise write. The guide says OAuth client registration across third
parties is "the slow, unglamorous part," and the README agrees in its own
words — providers "intentionally do not make this easy." That is a genuine
saving. It is also the single place where taking an early-access
dependency into the OWN IT tier's own function — credential mediation — is
hardest to defend, because P6's entire claim is that authorization is
*structural evidence in our records*, and a third-party Gatekeeper's
action log is not our record unless we project it.

`cfos_gatekeeper_log_ungrounded` is the refusal this needs: a Gatekeeper
action that did not land as a P6 `AuthorizationDecision` in our own store
is not evidence, it is someone else's log.

#### 2c — Cloudflare OS as an alternative *overlay host*

An application overlay (ADR 0063) is built for Cloudflare OS instead of
`FROM rails-base`.

**Substrate cost: zero, and not the substrate's call.** 0063 is explicit:
the substrate publishes base images and "does not know what is layered
onto them"; the application owns the deploy; two pins point one way. A
slot under `shapes-application/contracts/` names an application
identifier and does not carry its contracts — the 2026-09-04 amendment
settled that after six application shapes failed seven substrate gates at
once.

So an application that wants to be a Cloudflare OS gadget rather than a
Rails engine already may, and the substrate does not get a vote. What it
loses is the base image as its interface — it would consume the substrate
over CPCP/A2A (2a) instead of `FROM`.

**The real question 2c raises** is not whether it is allowed. It is
whether the gadget model is a *better* answer than 0063's thin-image
overlay to the question both answer: where does per-user application
surface live. Isolate-per-gadget makes per-user app instances economical
in a way container-per-application does not — the guide's §10 says
substituting containers for isolates "destroys the economics that make
per-user app instances viable." If the stack ever wants per-user
instances rather than per-application ones, 0063 is the ADR that has to
argue with that sentence, and it currently does not.

#### Direction 2, summed

| Reading | Substrate change | ADR engaged | Verdict |
|---|---|---|---|
| **2a** caller over A2A/CPCP | **none** | 0068 (already built) | **recommended** |
| **2b** capability provider under an adapter | submodule + adapter + pin gate | 0030, 0038, 0061 | defensible only if the delta is zero |
| **2c** alternative overlay host | **none — not our call** | 0063 | already permitted; raises a real question for 0063 |

**Claim direction 2 earns:** "a Cloudflare OS deployment can talk to the
governed pod, and an application may choose either host." Both true the
day the identity gate exists.

**Claim it does not earn:** "we support Cloudflare OS." 2a and 2c are
*interoperability by not caring* — the strongest kind, and the kind that
must not be oversold as integration.

---

### Direction 3 — Bake it in

**The position.** Cloudflare OS / `workerd` becomes part of the
substrate. The pod runs gadgets in isolates. Gatekeepers are the
credential mediation path. Cap'n Web or A2A rides between them. The
stack's contract layer is expressed on top of a runtime we do not own and
cannot upstream to.

**What this actually commits us to.** Not one decision — six, and five of
them amend accepted records.

| # | Commitment | Record it amends |
|---|---|---|
| 1 | A fourth language (TypeScript) in a container | ADR 0047 §1 |
| 2 | Boundaries that are not containers — isolates and facets | ADR 0047 §2, the load-bearing one |
| 3 | A permanent un-upstreamable delta on an early-access repo | ADR 0038, 0061 (which govern pins, not forks) |
| 4 | A second placement authority, over storage whose format is **[Unknown]** | ADR 0051, 0057 |
| 5 | A third RPC frame, or Cap'n Web replacing CPCP internally | ADR 0068 §4, 0066, 0067 |
| 6 | The guide's §5 control plane, *again*, for a second state model | `store_bindings.json`, 0052 |

Commitment 2 is the one that cannot be bought down. 1 is an amendment; 3
is a risk you can gate; 4, 5 and 6 are engineering. But "boundaries are
containers, exclusively" is what lets the twelve-container topology be
read off a compose file, and it is the direct expression of 0047's stated
tie-breaker. Concede it and the ContainerTopology diagram stops being the
architecture.

**The effort, taken from the guide's own §11 and not discounted:**
Phase 2 (`workerd` in production shape) is "weeks to months,"
undocumented, with DO persistence and placement named as the hard parts.
Phase 4 (security validation) 2–3 weeks, principal risk "silent loss of a
guarantee you assumed you inherited." Phase 5 cutover has **no confirmed
state-export path** — the guide says confirm one exists before promising
migration, "there may not be one." Phase 6 is permanent.

And the guide's own §12 checkpoint, which reads as though written for
exactly this decision: *"If the replace list has more than a handful of
load-bearing rows, reconsider whether a Cloudflare-account deployment
satisfies the actual constraint (often data residency, which may have
cheaper answers)."* Our replace list is short **because we already built
those rows.** The checkpoint's advice, applied to us, points away from
rehosting — not toward it.

**What would make direction 3 correct.** State the conditions plainly, so
this is a real option and not a straw man. All four, together:

1. **Per-user application instances become a requirement**, not a nicety.
   This is the one thing `workerd` gives that nothing here does.

   **Correction to the first draft.** That draft cited the guide's §10
   claim — that container-per-gadget "destroys the economics that make
   per-user app instances viable" — as the strongest argument for this
   direction. Read directly, **Cloudflare does not make that argument.**
   It is the guide author's inference. The README's case for per-user
   instances is a *product* thesis, not a cost one (README:54-62,
   150-156): every user runs their own copy **so that they can change it**
   — "no need to file a feature request, no need to beg the developer to
   prioritize it" — and a private instance per user means an app bug
   structurally cannot leak one user's data to another.

   This is a better argument than the economics one, and a harder one for
   ADR 0063 to answer. A thin-image overlay per *application* can be made
   cheap; it cannot make the application user-modifiable, because the
   image is built by the application repo and shared by everyone who runs
   it. If per-user modifiable surface is ever a requirement, 0063's model
   does not stretch to it at any price. If it is not, the whole argument
   for this direction evaporates — so this is the question to answer, and
   it is a product question, not an infrastructure one.
2. **Cloudflare ships the self-host tooling** and it is documented rather
   than COMING SOON, so commitment 6 is configuration instead of
   research.
3. **The delta is demonstrably zero** — configuration and separate
   packages only, per the guide's own advice and the
   `cloudflare-os-starter` precedent — so commitment 3 downgrades from a
   fork to a pin, and 0061's machinery suffices.
4. **The owner accepts amending 0047 §2 explicitly**, in a superseding
   ADR, with the cognitive-load cost priced. Not as a consequence
   discovered later in a coverage-gap row.

Until all four hold, direction 3 is a rewrite of the substrate's
doctrine to acquire a UI and an isolate tier, paid for by re-buying a
control plane we already run.

**Claim this direction earns, if taken:** per-user, user-modifiable
application instances and a shipped product surface used daily by a large
fraction of Cloudflare's own workforce (README:3).

**Claim it does not earn:** the security guarantees. §7 and §10 are
emphatic — these are *runtime* guarantees, and the guide says security
researchers raised unanswered questions about the isolation claims at
launch. Operating the runtime ourselves means we own the assurance, not
that we inherit it. Baking in buys the interface; the assurance is still
ours to prove.

---

## Comparison

| | 1 Ignore | 2a Caller | 2b Adapter | 2c Overlay host | 3 Bake in |
|---|---|---|---|---|---|
| Substrate code | none | none | adapter + pin | none | large |
| ADRs amended | none | none | none | none | **five** |
| New language | no | no | no | not ours | **yes** |
| Boundary model changed | no | no | no | no | **yes** |
| Fork / permanent delta | no | no | only if forced → refuse | no | **yes** |
| Upstream maturity exposure | none | none | one gated pin | not ours | **continuous** |
| Buys per-user modifiable instances | no | no | partially, remotely | yes, for that app | yes |
| Buys 12 shipped Gatekeepers | no | no | **yes** | no | yes |
| Buys B1–B5 (borrow list) | **yes** | yes | yes | yes | yes |
| Reversible | yes | yes | yes, pin removal | yes | **barely** |

---

## Borrow regardless of direction

The guide's §10 says that if a hard constraint forbids `workerd`, the
honest option is to borrow the *ideas*. The stack already has most of
them — capability introductions (P2), Gatekeeper-mediated credentials
(P6 + adapters + vault), observation tracking over derived artifacts
(P5 + P7). Two it does not, both cheap, both independent of which
direction is chosen:

**B1 — Deferred approval by simulation.** Confirmed first-hand, and the
README's rationale is better than the guide's summary of it (README:75-77).
The problem it names: synchronous human-in-the-loop means "you give your
agent a task, then walk away and get a coffee, only to come back and find
the agent got stuck on an approval on the first step" — so people set
auto-approve or `--dangerously-skip-permissions`, "which is, obviously,
unsafe." The mechanism: the Gatekeeper *simulates* the side-effecting
action locally, tells the agent it completed, serves simulated results on
read-back, and queues the real action for bulk approval later.

Nothing in the ADR corpus does this. P6 models the decision, the
credential reference and the revocation; it does not model *proceed
provisionally on a result that is not real yet*. The stack's nearest
neighbour is refuse-don't-raise, which stops the agent instead of letting
it continue — and the README's paragraph is an argument that stopping the
agent is why people disable the guardrail. That is worth taking seriously
as a critique of our own invariant, not just as a feature we lack.

It comes with its own required refusal: confirm a rejected action leaves
no partial real-world effect, and that a simulated result cannot be
mistaken for a real one downstream.
`simulated_result_consumed_as_real` is a refusal P6 should have whether or
not we ever see a Gatekeeper.

**B1a — the same idea has a transactionality plan.** `plans/step-transactionality.md`
exists upstream. If B1 is ever specified for P6, read that first rather
than re-deriving it.

**B2 — §7 as a conformance suite for our own shapes.** Five items,
written by someone who had to prove these properties without inheriting
them. Translated to this repo, with our own gate vocabulary:

| §7 item | Plant against magentic |
|---|---|
| 1 Default-deny | A fresh MIND session and a fresh overlay reach nothing until introduced (P2 reference-passing). |
| 2 Egress containment | ADR 0019 already: `validateTarget` refuses non-allowlisted origins and non-`https:`. Extend to: a reverse proxy misconfiguration in front of extract BACK does not widen it. The guide flags exactly this — "a misconfigured proxy or a relaxed CSP header silently breaks this." |
| 3 Credential isolation | MIND runs `api_key="switchyard-local"` and holds no provider secret (0019). Assert credentials never reach agent-authored code, logs, events or telemetry (0046). |
| 4 **Observation tracking across sharing** | The one worth the most, and now with a reference design — see B3. Have MIND read a restricted resource, derive an artifact, share it to a lower-privileged actor, confirm the **re-check denies them**. P5 + P6 give the *records* to answer who authorized what; whether anything *re-checks at share time* is an enforcement behaviour, not a shape, and the corpus does not say it exists. |
| 5 Deferred approval semantics | Blocked on B1. Nothing to test until the mechanism exists. |

**B3 — the observer mechanism, as a reference design for P6 + P7.** This
is the most valuable thing read in the repository, and it costs nothing to
take: it is a design, documented in prose, in `docs/observers.md`.

The property it enforces, in one sentence from that document: *when you
share a Gadget with someone, you are not giving them access to any
sensitive information that they did not have access to already.*

Six design moves are worth lifting, each of which answers a question P6
currently does not:

1. **The credential holder is the ACL authority, and the check runs in
   its trust domain.** The kernel does not reason about a vendor's
   identity model — "the gatekeeper is the authority on its own
   resource's ACL, so the check runs inside the gatekeeper's trust
   domain." For us: the adapter decides, not BACK. P6's
   `AuthorizationDecision` would record the outcome, not compute it.
2. **The verifier pattern.** The prospective observer's *own* connected
   account mints an opaque verifier, which the kernel hands back to the
   gatekeeper to unwrap. The kernel never learns the vendor-level
   identity. This is how "check whether Bob may see this" is asked
   without the asker holding Bob's credential — directly relevant to
   ADR 0019's principle that the router holds the credential and the
   agent holds nothing.
3. **An opaque observer id, deliberately not the email**, "to avoid
   tempting gatekeeper authors to parse identity out of it — identity is
   conveyed only via the verifier." A small decision with a large
   consequence: it makes the boundary un-bypassable by convention rather
   than by review. This is the same instinct as P6's
   `invalid-literal-secret` fixture, applied to identity.
4. **Intent and verification are two separate records, and both are
   required.** The sharing table records the owner's *intent*; the
   observer record records *configured-and-verified*. Opening needs
   reachability in the sharing graph **and** a valid observer record.
   P6 currently models something like the first and nothing like the
   second.
5. **Authorization keys off the sharing graph, never off live sessions** —
   because a gadget may store observed data and re-display it much later.
   The magentic analogue is exact: a derived artifact in BACK outlives
   the session that produced it, so any re-check must key off durable
   authorization state, not session state.
6. **Re-verify on every open, and state the residual.** Revocation is
   lazy and the document says so plainly: a collaborator who never opens
   again is never re-checked, and sessions they already hold keep the
   access their own open verified. Scope *widening* triggers a workspace
   restart (~100 ms) so live sessions re-verify; scope *shrinking* needs
   no restart, because a narrower scope can never under-verify a session
   admitted at the wider one. That asymmetry is a reusable rule.

**What makes this document trustworthy, and worth imitating as a
document.** It ledgers its own fail-open cases at the point of the
mechanism that fails, with the required fix named: a mid-registration
observer read as unknown ("fail-open... persistent, since it lands in
chat history"); `enableHook` not aborting gadget-minted children; an
agent turn started by an external message outliving its verification
lease, "tolerated only because nothing calls `receiveExternalMessage`
yet." That last one is the house style of this repo's own ADRs —
the unenforced-and-named pattern of ADR 0020's empty `enforced_by`, or
0047's 23 out-of-policy Python files. Convergent practice, independently
arrived at.

**B4 — the strategy table as a classification for credential adapters.**
`docs/observers.md` §9 assigns every gatekeeper resource type one of five
strategies: **A** private-only (`addObserver` always throws), **B** ACL
check on a single atomic unit, **C** data-set tracking (log what was
touched, verify each observer against every logged set, exclude on
failure), **D** low-stakes no-op, **N** not applicable. Strategy is chosen
**per resource type, not per package** — `gatekeeper-google` spans B, C
and A across Docs, BigQuery and Gmail.

And the test for when a broad binding needs C rather than B, which is the
genuinely portable insight — both must hold:

1. the broad binding spans sub-resources with **distinct ACLs**, and
2. there is a **per-observer access oracle** to check each sub-resource
   against.

Fail (1) → B, one ACL already covers everything. Fail (2) → D or A: "you
can log what was touched but cannot verify anyone against it." That
sentence is the whole reason Home Assistant is D and Gmail is A. It is a
better-stated version of a question `gems/adapters/` will face for every
upstream it wraps, and it is stealable verbatim into P6's prose.

**B5 — auth config that a compromised admin cannot change.**
`REVIEW.md` records that `AUTH_GATEKEEPERS` and `DISABLE_PASSWORD_AUTH`
are "deliberately env-var driven and must **not** move into
`AdminConfig`, so a compromised admin session cannot change it. Reject
changes that relocate it." That is ADR 0046's read-back asymmetry
argument applied to authentication configuration rather than secrets, and
the stack has no equivalent rule for the config surface. Worth one line
in 0046 or its successor.

Item 4 above remains the finding this document most wants surfaced: it is
a plantable test against `proposed` profiles, it does not need Cloudflare
OS in our tree in any form, and there is now a worked design to plant
against.

---

## Non-goals

- Forking Cloudflare OS. Under ADR 0038 and 0061 there is no such thing
  as a gated fork here; there are pins and there are refusals.
- Running the pod on Cloudflare's managed network. That trades the
  offline boundary and the privacy commitment (GOVERNANCE, charter) for
  a control plane we already operate.
- Cap'n Web on `/_cpcp/rpc`. ADR 0068 §4 already refused a second frame
  on that path; a third gets the same answer.
- `workerd` inside MIND. MIND is the agent runtime and ephemeral
  inference state (0057). Same refusal as `3b` in the DuckDB paths.
- Cloudflare OS shapes in `gems/shapes-application/contracts/`. The
  2026-09-04b amendment settled this class of move: an application's —
  or a host's — contracts do not enter the substrate's manifests.
- A container-count argument in this file. Direction 3 changes the
  count; 1, 2a and 2c do not; 2b adds none. Owner names the number if 3
  is ever taken.
- Treating §7 as inherited. The guide's own warning, and it applies to
  our profiles as much as to their runtime.

---

## Open questions (owner)

1. **Which direction.** Recommendation: **1 plus 2a** — record the
   non-adoption in a short ADR, and let ADR 0068's host binding be the
   whole of the interoperability story. 2a is already built; it needs the
   identity gate, which is owed regardless.
2. **2b: are twelve shipped Gatekeepers worth one early-access pin?**
   Recommendation: **not yet**, and specifically not until P6 moves from
   `proposed` to implemented — otherwise we would be importing credential
   mediation before owning the evidence shape it is supposed to produce.
   **Named trigger to revisit:** Cloudflare shipping the standalone
   Gatekeeper services README:79 envisions. That, not the `workerd`
   tooling, is what makes 2b clean.
3. **Does anything re-check permission when a derived artifact is
   shared?** §7.4 translated to our shapes. Still the highest-value plant
   in this document, still independent of directions 1–3, and now with
   B3 as a reference design to plant against rather than a blank page.
   Recommendation: write it now, against P5 + P6. Specifically, decide
   whether magentic wants B3's move 4 — intent and verification as two
   separate records, both required — because that is a shape question P6
   can answer today and it does not depend on any other open item here.
4. **Should P6 gain deferred-approval-by-simulation (B1)?**
   Recommendation: yes, as an amendment when P6 is implemented, with
   `simulated_result_consumed_as_real` as a stated refusal. Not a new
   profile. Read `plans/step-transactionality.md` upstream first. Note
   this one cuts against refuse-don't-raise, so it is a charter-level
   conversation, not only a profile edit.
5. **Does ADR 0063 need to argue with per-user gadget instances?**
   Reframed after reading the source: the challenge is not the guide's
   isolate-economics claim (which Cloudflare does not make) but the
   README's product thesis — per-user instances exist so the *user can
   modify the application*. A thin-image overlay can be made cheap; it
   cannot be made user-modifiable. Recommendation: a paragraph in 0063,
   or a superseding record, stating whether per-user modifiable
   application surface is a requirement the substrate intends to meet.
   If it is, direction 3's condition 1 is live and this document should
   be re-read end to end.
6. **Who owns the identity gate?** Absent in every direction, and the
   one item on this list that is owed whatever the owner decides. Note
   the asymmetry the source read exposed: Cloudflare OS *ships* self-host
   auth (built-in username/password, or gatekeeper sign-in keyed on
   verified email), and the pod has nothing. The guide marked its §6.1
   equivalent `[Unknown]`; for us it is not unknown, it is absent.
   Recommendation: name an owner before 2a is described to anyone as
   working.
7. **Is B4's two-criteria test worth adopting for `gems/adapters/`?**
   Every adapter that wraps a credentialed upstream faces "can I verify
   another party's access to what this already read." Recommendation:
   yes, as prose in P6 — it costs nothing and it is better stated
   upstream than we would state it cold.

---

## What we take from the source, and what we leave

**Take, from the repository.** The observer mechanism as a reference
design for P6 and P7 (B3), the per-resource strategy table and its
two-criteria test (B4), deferred approval by simulation and the argument
for why synchronous approval fails in practice (B1), the env-var auth
rule (B5). Also the habit the source documents display: ledgering
fail-open cases at the mechanism that fails, with the required fix named
and the reason it is tolerated stated. This repo already does that; it is
worth noticing that a team operating at Cloudflare's scale converged on
the same practice.

**Take, from the guide.** The replace-list and control-plane inventory,
scored against our own tree — the clearest external audit of what this
substrate already owns that anyone has written, and its author was not
thinking about us. The §7 test list. The contribution policy, which
converts "adopt Cloudflare OS" from an integration question into a fork
question, and which the repository confirms verbatim.

**Leave.** The guide's recommendation. It recommends Path A — rehost on
`workerd` — to a reader who wants Cloudflare OS off Cloudflare's network.
We are not that reader: we are not trying to keep a Cloudflare OS
deployment, we are deciding whether to acquire one. Its §12 checkpoints,
applied honestly to a substrate that already owns SWITCH, persist, the
CPCP seam and the container boundary, point at direction 1, not Path A.

**Leave also — the guide's isolate-economics argument.** The first draft
of this file repeated it as direction 3's strongest support. The
repository does not make it. Cloudflare's argument for per-user instances
is a product argument about user-modifiable software, and that is the one
to answer (open question 5). A claim that survives only until you read the
primary source is not an argument worth carrying.

**Leave also.** Any claim that the overlap validates our profiles. Two
systems converging on capability-mediated introductions with an audit
trail is evidence the *idea* is right. P6 and P7 are still `proposed`,
still Manus-drafted, still unimplemented. Convergence is not
implementation, and this file must not be cited as though it were.
