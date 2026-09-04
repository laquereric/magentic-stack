# The Magentic Stack

> **You do not need to chase the next AI framework.** Magentic absorbs upstream
> churn and gives your organization a governed language for what AI *reads,
> decides, does, and learns.*

The Magentic Stack is the bridge between fast-moving frontier-AI upstreams and
stable enterprise operations. It **grounds (owns)** the enterprise-facing
contract while **following** upstream capability providers behind pinned seams.
The result: enterprises adopt AI through a shared *language* and a bounded
*governance surface* rather than through yet another app.

> This repository is the **strategic map + reference scaffold** for the stack.
> Each area declares its ownership tier and points at the canonical source repo
> that implements it. It is intentionally a boundary map first, code second.

---

## The thesis in one paragraph

Frontier AI churns on a ~90-day loop. Governing enterprises cannot absorb that
churn unless there is (a) a stable **grounding language** and (b) a bounded
**governance surface**. Magentic owns the language (OSI Level 8) and the
governed component (the 5-container Pod including the MIND container), and *follows* the forward looking runtimes and routers (NVIDIA NOOA, NeMo Switchyard) as pinned, replaceable dependencies. Downstream experimentation stays fast; the enterprise contract stays stable and auditable.

---

## Ownership legend — read the tree as a boundary

The single most important thing this repository encodes is an **ownership
boundary**. Every top-level area is exactly one of three tiers:

| Tier | Meaning | Areas |
|---|---|---|
| 🟢 **OWN IT** | Durable, Magentic-owned — the enterprise truth boundary. Changes are deliberate, versioned, and contract-driven. | `grammar/` · `gems/` · `runtimes/` |
| 🔵 **OFFICIAL** | Magentic-built products and developer surfaces. | `apps/` · `plugins/` |
| 🟡 **FOLLOW THEM** | Upstream dependencies. **Pinned, never forked**; reached only through adapters. | `upstreams/` |

**Rule of thumb: own the language and the contracts; follow the runtimes and routers.**

---

## The three grounding constructs

1. **Grounding language — OSI Level 8.** A stable, machine-readable contract layer
   that translates upstream AI capabilities into enterprise actions via **Context**
   and **Effect**, constrained by **closed SHACL shapes**. The backbone that makes
   downstream experimentation auditable and governable. → `grammar/`

2. **Governance pod — the 5-container MIND centered Pod.** Separates the transient agent
   runtime from durable governance surfaces so the enterprise surface stays stable
   while upstream churn runs behind pinned seams: **FRONT, BACK, BackJob, GRAPH,
   MIND**. → `runtimes/`

3. **Adoption flywheel — SwitchYard → ThreeDot → MagenticMarket.**
   **SwitchYard** (free online/offline routing) drives developer adoption →
   **ThreeDot** grounds the CPCP/OSI-8 calls in the editor → **MagenticMarket**
   provides a marketplace for verified offers *without data inspection.*
   → `apps/` and `plugins/`

```
  developer adoption          grounded calls            verified offers
   SwitchYard        ──→        ThreeDot        ──→        MagenticMarket
  (route online/offline)   (CPCP/OSI-8 in editor)   (offers, attestation, policy digest)
```

---

## Repository map

```
magentic-stack/
├── README.md                 # this file — strategic map, ownership legend, quick start
├── docs/                     # board / architecture / runbooks / ADR / security
├── grammar/          🟢      # OWN IT — durable language; normative specs + conformance
│   ├── osi-level-8/          #   normative spec, profiles, SHACL shapes
│   ├── cpcp/                #   cyborg-pod-contract-package
│   └── conformance/         #   Profile 1–8 tests
├── gems/       🟢      # OWN IT — adapters and rails backends
│   ├── rails-cpcp/          #   CPCP seam implementation
│   ├── rails-osi-level-8/   #   OSI-8 grounding helpers
│   └── adapters/            #   boundary adapters for upstreams/marketplaces
├── runtimes/         🟢      # OWN IT — governance plane and pod runtime (5-container MIND Pod)
│   ├── mind-pod/            #   MIND runs the agent in isolation
│   ├── back/                #   BACK service: Context / Memory / /_cpcp
│   ├── front/               #   FRONT UI and bounded MIND view
│   ├── backjob/             #   durable work
│   └── graph/               #   Oxigraph RDF projected from the Rails models
├── apps/             🔵      # OFFICIAL products / surfaces
│   ├── switchyard-online/          #   EXTERNAL / uncoupled (switchyard.online)
│   ├── switchyard-offline/         #   private/local plugin surface
│   └── magentic-market/           #   EXTERNAL / uncoupled (Gate 3 offer contract)
├── plugins/          🔵      # OFFICIAL developer tooling
│   ├── threedot-vscode/     #   VS Code webview shell
│   ├── threedot-back/       #   Rails backend for ThreeDot
│   ├── switchyard-routing/  #   Switchyard LLM-assisted routing (ThreeDot assist via CPCP)
│   └── shacl-reader/        #   SHACL inspection tooling
├── upstreams/        🟡      # FOLLOW THEM — immutable pins (never forked)
│   ├── nooa/                #   pinned NVIDIA NOOA
│   ├── nemo-switchyard/     #   pinned NVIDIA Switchyard
│   ├── json-rpc-ld/         #   pinned spec CPCP profiles (ADR 0048)
│   └── manifests/           #   SBOMs, provenance, patch records, pin files
├── integration-tests/        # validation and governance tests
├── deploy/                   # container / orchestration for the governed pod
├── tooling/                  # dev env and CI tooling
└── .github/                  # CI gates for SHACL conformance, SBOM, etc.
```

---

## Where the code lives

**This repo is closed (ADR 0038).** Every gem, tool and runtime in it lives here
and nowhere else. The standalone repos these areas came from were archived on
2026-08-27 -- readable and cloneable, but not the place to edit.

| Area | Contents | Tier |
|---|---|---|
| `gems/` | the owned contract layer -- 12 gems, all built from the root `Gemfile` | OWN IT |
| `grammar/osi-level-8` | OSI Level 8 spec prose (shapes live in `gems/osi-level-8-profiles`, ADR 0022) | OWN IT |
| `grammar/cpcp` | CPCP normative spec (scaffold) | OWN IT |
| `tooling/` | docker-swap, slo, boundary + shacl checks | OWN IT |
| `runtimes/effect-plane` | effect classification | OWN IT |
| `runtimes/mind-pod` | container app; Gate 1 Part C exercises it under docker | OWN IT |
| `upstreams/nooa` | [NVIDIA-NeMo/labs-OO-Agents](https://github.com/NVIDIA-NeMo/labs-OO-Agents) | FOLLOW (submodule, pinned) |
| `upstreams/nemo-switchyard` | [NVIDIA-NeMo/Switchyard](https://github.com/NVIDIA-NeMo/Switchyard) | FOLLOW (submodule, pinned) |
| `upstreams/json-rpc-ld` | [laquereric/json-rpc-ld](https://github.com/laquereric/json-rpc-ld) | FOLLOW (submodule, pinned; spec only) |

`app-switchyard-online` and MagenticMarket are **uncoupled** products: separate
repos that interoperate over CPCP, not vendored here and not archived.

Provenance -- which archived repo each area came from -- is in
[`docs/SOURCE_STATUS.md`](docs/SOURCE_STATUS.md).

### Consuming a gem from here

    gem "mmg-acia", git: "https://github.com/laquereric/magentic-stack.git",
        glob: "gems/mmg-acia/*.gemspec", ref: "<sha>"

One clone serves many gems. Do not pin an archived standalone.

---

## Developer quick start

> **Build from a single clone.** magentic-stack is the canonical source of truth: owned code is vendored in (git subtree) and wired via Bundler path gems / per-package npm / Cargo workspace; upstreams are pinned submodules. See [`docs/plans/`](docs/plans/) and [ADR 0002](docs/adr/0002-self-referential-consolidation.md).

```bash
# Upstreams are git submodules — clone recursively.
git clone --recursive https://github.com/laquereric/magentic-stack.git
cd magentic-stack

# One command bootstraps the whole stack (see docs/plans/self-referential-build.md):
#   Checks prerequisites (docker, git, bundle, npm, cargo) first — fails fast if required tools missing
#   init/pin upstream submodules -> build all workspaces -> bring up the MIND pod -> smoke-test /_cpcp
./bootstrap

# 1. Read the boundary. The tree IS the doc — start with this README's legend.
# 2. Pick your entry point:
#    - Standards / contracts ....... grammar/   (start: grammar/osi-level-8/README.md)
#    - Rails integration ........... gems/rails-cpcp/README.md
#    - Governance pod runtime ...... runtimes/README.md
#    - Developer tooling ........... plugins/threedot-vscode/README.md
# 3. Governance & contribution rules: GOVERNANCE.md and CONTRIBUTING.md
```

**Ground one workflow.** The fastest way to understand the stack is to map a
single real workflow onto Context → Effect → authorization evidence → outcome,
validate it against the closed SHACL shapes in `grammar/`, and run it through the
`/_cpcp` seam in `gems/rails-cpcp/`.

---

## Governance in four rules

1. **Boundary ownership.** `grammar/`, `gems/`, `runtimes/`, `apps/`, and
   `plugins/` are Magentic-owned. `upstreams/` is a tracked dependency area.
2. **Release integrity.** Every release records source revision, license, SBOM,
   provenance, conformance results, and rollback targets for NOOA and Switchyard pins.
3. **Contract authority.** SHACL shapes and normative profiles are the
   authoritative spec. Generated code and interfaces derive from these contracts.
4. **Privacy commitment.** Offline boundary tests and explicit opt-in analytics
   governance apply to all telemetry.

See [`GOVERNANCE.md`](GOVERNANCE.md) for the full policy.

---

## References

1. Kapil Ahuja, *The CTO’s Achilles Heel for AI Adoption: Building the Bridge to the Enterprise.* <https://medium.com/activated-thinker/the-ctos-achilles-heel-for-ai-adoption-building-the-bridge-to-the-enterprise-77fe538c66cd>
2. Enrique Dans, *Enterprise AI doesn’t need another app: it needs its language.* <https://www.fastcompany.com/91584370/enterprise-ai-doesnt-need-another-app-it-needs-its-language>
3. OSI Level 8 public repository (archived 2026-08-27; the spec now lives at `grammar/osi-level-8` here). <https://github.com/laquereric/osi-level-8>
4. NVIDIA NeMo labs-OO-Agents (NOOA). <https://github.com/NVIDIA-NeMo/labs-OO-Agents>
5. NVIDIA NeMo Switchyard. <https://github.com/NVIDIA-NeMo/Switchyard>

---

## License

Apache License 2.0 — see [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
Upstreams under `upstreams/` remain under their own licenses and are pinned, not forked.
