# Cloudflare OS and the Magentic Stack — a reasoned contrast

Two systems, built independently, that converged on the same problem:
**how does an AI agent reach an enterprise resource without the reach
becoming the vulnerability?** They answer it differently, and the
differences are not arbitrary — each follows from a prior commitment
about what is being optimised.

This file is the contrast. The *decision* about what to do with it is
[`CloudflareOs_3_directions.md`](CloudflareOs_3_directions.md); the one
thing adopted so far is ADR
[0070](../adr/0070-never-persist-datasets-and-the-inverted-observer-seam.md).

**Sources.** Cloudflare OS read directly at HEAD `08afe059`
(Apache 2.0): `README.md`, `CONTRIBUTING.md`, `REVIEW.md`,
`docs/observers.md`, `docs/public-server.md`, `docs/sharing.md`,
`plans/gatekeeper-kit.md`, `wrangler.jsonc`, `packages/`. Magentic read
from this tree. Where a claim here is inference rather than something
either repository states, it says so.

---

## 1. The two theses, in each project's own words

**Cloudflare OS** (README:18): *"We are making Cloudflare OS open source
so that others can copy it and customize it for their own company. The
idea is not that your company uses Cloudflare OS, but rather that you
make it 'Your Company OS'."*

It is a **product** — a shipped agent environment used daily across
Cloudflare's own workforce — offered as a thing to fork and rename. Its
unit of value is the running system.

**Magentic** (README, "The thesis in one paragraph"): *"Frontier AI
churns on a ~90-day loop. Governing enterprises cannot absorb that churn
unless there is (a) a stable grounding language and (b) a bounded
governance surface."*

It is a **contract layer** — a language plus a governed component,
following runtimes behind pinned seams. Its unit of value is the
boundary.

Everything downstream follows from this. A product optimises for the
user's next hour; a contract optimises for the tenth re-pin. Neither is
a better goal, and most of the divergences below are this one difference
appearing again in a new place.

---

## 2. Where they agree, independently

The agreements matter more than the differences, because they were
reached without contact. Four of them:

| Both hold | Cloudflare OS | Magentic |
|---|---|---|
| **Default-deny; access comes by explicit introduction, not configuration** | "Each agent, and each Gadget, by default has access to nothing… you must *introduce* each agent to any particular resources" (README:166-170) | P2 reference-passing (ADR 0023); base-profile default-deny |
| **The agent holds no credential** | Credentials live in the Gatekeeper Worker; agent-authored code never sees them | MIND runs `api_key="switchyard-local"` and holds no provider secret (ADR 0019) |
| **Ambient access is the anti-pattern** | "This differs from most agent harnesses, where MCP servers are configured upfront, making broad access to all your services ambiently available" | ADR 0026's premise: "Ambient permission — the call succeeded, so it must have been allowed — cannot be audited" |
| **Capability-based, not ACL-based, for agents** | "The ideal security model for all of this is capability-based security, not access control lists" (README:112) | OSI-8 Context/Effect with closed SHACL shapes; P6 evidence bound to a specific Effect |

That two teams with no shared code, no shared vocabulary and different
substrates landed on default-deny-plus-introduction and
credential-never-reaches-the-agent is the strongest available evidence
that both are right about the problem. It says nothing about whether
either is right about the solution.

A fifth agreement is about *practice* rather than architecture, and it
surprised me: both projects ledger their own unenforced rules at the
site of the mechanism that fails. Cloudflare's `docs/observers.md` names
three fail-open cases with the required fix and the reason each is
tolerated ("tolerated only because nothing calls
`receiveExternalMessage` yet"). This repo does the same thing with
`unenforced_because`, ADR 0020's empty `enforced_by`, and 0047's 23
out-of-policy Python files. Convergent honesty conventions.

---

## 3. The structural contrast

| Dimension | Cloudflare OS | Magentic Stack |
|---|---|---|
| **Unit of value** | a running product | a contract boundary |
| **Boundary primitive** | isolate, Durable Object facet | **container, exclusively** (ADR 0047 §2) |
| **Isolation granularity** | per user, per gadget | per role, per pod |
| **Language** | TypeScript throughout | Python (MIND), Rust (SWITCH, declared), Ruby-in-Rails-form (everything else) |
| **Kernel** | `packages/workshop-backend`, "maintainers read every line" (`REVIEW.md`) | the `/_cpcp` seam + `seam_authority.json`; every served method manifested |
| **RPC** | Cap'n Web object-capability | CPCP JSON-RPC-LD; A2A over NATS in-pod, HTTP on the host binding (0066-0068) |
| **State per unit** | per-facet SQLite, durable by design | three kinds, three owners (0057); closed store set + writer-sets, gated |
| **Placement** | the runtime's | PERSIST's, next-boot only, never live (0051) |
| **Contract form** | TypeScript interfaces + JSDoc, reviewed by humans | closed SHACL shapes, authored in LinkML, reified (0069); contract wins over code |
| **Authorization** | enforced at admission, per-open, inside the gatekeeper's trust domain | P6 structural evidence, journal-derived admission (0052) — **`proposed`, unimplemented** |
| **Identity** | ships: username/password, or `AUTH_GATEKEEPERS` sign-in keyed on verified email | **none.** `actor_proven: false` (0040) |
| **Upstream posture** | is the upstream; not accepting contributions | pins upstreams, never forks (0038); adapters are the sole path (0030) |
| **Maturity** | early access, v2 rewrite, `compatibility_date` nine days old at time of writing | pre-alpha pin held still by a gate with a re-review record (0061) |

### The single deepest difference

**Cloudflare OS makes persistence safe. Magentic (per ADR 0070) refuses
persistence.**

Everything else is downstream of this. Their gadget stores what it read
— that is the product, since a gadget is your private, modifiable app
with its own state. Storing observed data means a second viewer may
later see what the first one read, which is a real leak, so they built
the mechanism that makes it safe: observer records, per-vendor
verifiers, `addObserver` checks in the credential holder's trust domain,
forward exclusion, re-verification every open, workspace restart when
verification scope widens.

It is a careful mechanism and it has a price. It needs a **per-observer
access oracle** for every resource type, and where the source provides
none, the model gives something up. Their own decision table records
where:

| Source | Strategy | What is surrendered |
|---|---|---|
| Gmail | **A** — `addObserver` always throws | **sharing.** A gadget that read Gmail cannot be shared with anyone |
| Home Assistant | **D** — no-op | **enforcement.** "HA exposes no per-user/per-entity ACL oracle to check against" |
| Spotify | **D** — no-op | enforcement, deliberately (low stakes) |

ADR 0070 inverts the question. If a dataset is never persisted and each
viewer's own credentialed read is the check, then *"may Bob see what
Alice read?"* is never asked — Bob reads it himself, and the source
enforces its own ACL as a side effect of answering. No oracle, no
observer records, no forward exclusion, no restart-on-widening.

**And they already hold half of that move.** `docs/sharing.md`: a
`build` collaborator uses "their own connected accounts for bindings…
not the owner's. This prevents collaborators from gaining access to the
owner's accounts beyond what the gadget's existing bindings already
expose." Same for models — AI billing goes to whoever prompted, not the
gadget owner.

So per-user credentials are not the differentiator; **retention is.**
Cloudflare reads with the collaborator's own account and then lets the
result persist into shared gadget state, which is exactly why the
observer ledger has to exist. ADR 0070 is their per-user-credential move
plus a retention rule — a smaller delta than it first appears, and the
half we are keeping is the half already proven at Cloudflare's scale.

The consequence worth stating plainly: the two cases where Cloudflare
must abandon either sharing or enforcement are both served under 0070
without abandoning either. That is the sharpest capability difference
between the two systems, and it runs in our favour.

The countervailing cost is equally real, and it is not small: N reads
for N viewers, and **divergent views** — Alice sees her rows, Bob sees
his, so "look at row 5" no longer refers. Cloudflare chose *uniform
view, restricted audience*; 0070 chooses *universal audience, divergent
view*. Their choice is better for collaboration on a shared reality.
Ours is better for a small group with mixed entitlements, and it is the
only one of the two that works when the source has no oracle.

---

## 4. What each system already owns that the other must build

Read as an audit, this cuts both ways, and honestly.

### Cloudflare OS ships what we have not built

| Capability | Theirs | Ours |
|---|---|---|
| Authorization enforcement | **built**, with a per-resource strategy for every gatekeeper | P6 `proposed`, no implementation |
| Observation tracking across sharing | **built** (`docs/observers.md`) | P5 + P7 `proposed` |
| Identity | **ships** two paths | **absent**; `actor_proven: false` |
| Deferred approval of side-effecting actions | **built** — simulate, queue, approve in bulk later | nothing; refuse-don't-raise stops the agent instead |
| Credentialed integrations | 12 service Gatekeepers + a kit + a `write-gatekeeper` skill | `gems/adapters/` |
| A UI anyone uses daily | yes, across Cloudflare | FRONT, and the overlay pattern |

### We own what a rehost of theirs requires you to build

Scored against the rehost guide's §5, the phase it calls "the largest
and least-documented":

| Responsibility Cloudflare provides invisibly | Magentic equivalent | State |
|---|---|---|
| Durable Object placement and routing | PERSIST, placement authority over a closed store set | **live** |
| Persistence format, backup, writer identity | `store_bindings.json` closed paths + writer-sets; journal is the only admission truth (0052) | **live and gated** |
| Rolling upgrades / process supervision | no live swap of a running process's store; restart applies | **decided** |
| Model routing, spend caps, attribution | SWITCH: content-blind, credential-holding, allowlisted TLS-only egress, two-port split (0019) | **live** |
| Governed access to existing MCP servers | the CPCP seam, `seam_authority.json`, `boundary_manifest.json` | **live** |
| Observability | LOG as thirteenth container (0058) | **decided, unbuilt** |

**The asymmetry this exposes.** The marginal value of adopting
Cloudflare OS is concentrated in the things that cost most to take — the
per-user isolate tier and the product UI — while most of what a rehost
obliges you to build, we already run. That is why the analysis in
`CloudflareOs_3_directions.md` lands on *borrow the ideas, decline the
substrate*, and why the borrow list turned out to be worth more than the
integration.

---

## 5. Where the contrast is a warning rather than a comparison

Three places where reading their system should change how we talk about
ours.

**Their kernel has a named review bar; our equivalent is distributed.**
`REVIEW.md` says `workshop-backend` and the public API in
`workshop-shared/src/api.ts` are the kernel, that maintainers read every
line, and that a large kernel change must be split so the kernel can be
reviewed apart from UI. We have the register (`seam_authority.json`,
`boundary_manifest.json`) and the gates, which is arguably stronger —
but no statement of which code gets human eyes on every line. Our
equivalent is a gate, theirs is a person. Gates do not catch design.

**They get default-deny from the type system, for free.** Their
restricted capability is a class that `implements Overseer` and throws
`Unauthorized` outside an allowlist, so — `docs/sharing.md` — "any
newly-added interface method fails to compile until a developer
consciously decides whether `use` callers may invoke it (default-deny)."
The new method cannot be forgotten, because the build stops. Our
equivalent is `boundary_manifest.json` plus a gate, which catches the
same omission at CI rather than at compile, and only for methods someone
remembered to manifest. Worth knowing that a cheaper mechanism exists
for this specific class of omission; not an argument for TypeScript.

**They shipped authorization; we shipped the evidence shape for it, and
called that the hard part.** P6 is `proposed` and Manus-drafted. Their
`docs/observers.md` is a working mechanism with its fail-open cases
ledgered. The honest reading is that specifying evidence is the easier
half and we should stop describing the profile corpus as though the
remaining work were implementation detail. ADR 0070's blocker section
exists to prevent exactly that elision.

**Their agent-experience argument is a critique of our invariant.**
README:75 — synchronous human-in-the-loop means "you give your agent a
task, then walk away and get a coffee, only to come back and find the
agent got stuck on an approval on the first step," which is why people
reach for `--dangerously-skip-permissions`. Refuse-don't-raise (charter,
row 49) stops the agent. That is the behaviour their paragraph says
drives users to switch the guardrail off. We do not have to adopt
simulation, but we should stop treating refusal as costless.

---

## 6. What we took, and why only that

Adopted: **ADR 0070**, which takes the *seam* — the credential holder is
the authority and the check runs in its trust domain — and inverts the
question so that the ledger enforcing it is never needed.

Recorded but not adopted, each with the reason:

| Idea | Status | Why not yet |
|---|---|---|
| Deferred approval by simulation | candidate P6 amendment | cuts against refuse-don't-raise; a charter-level conversation, not a profile edit |
| The A/B/C/D/N strategy table | candidate P6 prose | under 0070 we need no oracle, so the table has no work to do — but its two-criteria test for broad bindings is a good question for any adapter |
| Env-var auth config a compromised admin cannot change | candidate 0046 successor | ADR 0046's read-back asymmetry applied to config rather than secrets; we have no equivalent rule |
| Gatekeepers as a pinned dependency | declined for now | early-access, and useful consumption may need the permanent delta ADR 0038 refuses. Revisit if Cloudflare ships the standalone Gatekeeper services README:79 envisions |
| `workerd` / isolate tier | declined | amends ADR 0047 §2, the load-bearing simplification of the container topology |

**Why the borrow list is short by design.** Under ADR 0038 upstreams are
pinned and never forked, and `gems/adapters/` is the sole path to them
(0030). An *idea* crosses that boundary for free; code does not. So the
correct thing to import from a system we admire but will not depend on
is its reasoning — which is also the only part that does not need
re-pinning every 90 days.

---

## 7. What this contrast does not decide

- **Whether per-user, user-modifiable application surface is a
  requirement.** This is the one capability `workerd` provides that
  nothing here does, and Cloudflare's argument for it is a product
  thesis, not a cost one: every user runs their own copy *so they can
  change it*. ADR 0063's thin-image overlay can be made cheap; it cannot
  be made user-modifiable. Open question 5 in
  `CloudflareOs_3_directions.md`.
- **Who owns the identity gate.** Absent here, shipped there, and now
  the stated precondition of ADR 0070.
- **Whether 0070's divergent-view semantic survives contact with a real
  shared board.** `plan_sharedai_canvas.md` is where that gets tested.
- **Anything about container count.** 0070 is a store rule and adds no
  container.

---

## 8. Sources

- `/Users/ericlaquer/NoIcloud/cloudflare-os` at HEAD `08afe059`, Apache 2.0.
- `magentic-market-ai/docs/research/cloudflare-os-rehost-process.md` —
  the rehost process guide, whose §4/§5 inventory supplied the audit
  frame in section 4. Its §10 isolate-economics argument is **the
  author's inference and not a Cloudflare claim**; see
  `CloudflareOs_3_directions.md`.
- This tree: ADRs 0019, 0023, 0026, 0027, 0030, 0038, 0040, 0046, 0047,
  0051, 0052, 0057, 0061, 0063, 0065-0069, 0070; `README.md`;
  `GOVERNANCE.md`; `ContainerTopology.md`.
