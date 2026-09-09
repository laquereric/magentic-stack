# Architecture Overview

## The bridge

The Magentic Stack sits between fast-moving frontier-AI upstreams and stable
enterprise operations. It **owns** the enterprise-facing contract and **follows**
upstream capability providers behind pinned seams.

```
  UPSTREAM (churns ~90d)          MAGENTIC (stable)                 ENTERPRISE
  NVIDIA NOOA / Switchyard  ───▶  adapters → OSI-8 contract  ───▶  governed actions
  (pinned, never forked)          (SHACL-constrained)               (auditable, reversible)
```

## The grounding language — OSI Level 8

OSI Level 8 is a stable, machine-readable contract layer. It expresses what an AI
capability may **read** (Context) and **do** (Effect), constrained by closed
**SHACL shapes**. Because the contract is stable and validated, downstream
experimentation is auditable and governable. Lives in `grammar/`.

## The governance pod — 12-container MIND Pod

The MIND Pod separates the transient agent runtime from durable governance
surfaces so the enterprise surface stays stable while upstream churns. Twelve
containers run today; `ContainerTopology.md` is the measured authority.

| Container | Role |
|---|---|
| **FRONT** | UI + a bounded view onto MIND. The only surface users see. DBless. |
| **BACK**  | Context / Memory / the `/_cpcp` contract seam. Declared domain writer. |
| **BackJob** | Durable, asynchronous work. Declared co-writer. |
| **BUS** | CPCP seam plus an async projection of metadata derived from BACK's journal. Not the broker. |
| **PERSIST** | Placement authority for every store; answers set/get, refuses writer-sets. |
| **VAULT** | Live CPCP seam holding provider credentials. `put`/`list`, never `get` from CONFIG. |
| **CONFIG** | Operator UI on `:13003`; vault's first caller. |
| **SHAPE** | GET retrieval of shapes, DBless. Serves TTL at runtime. |
| **MIND**  | Runs the (upstream) agent in OS-level isolation. Cannot bypass evidence paths. |
| **SWITCH** | The LLM plane (Node). Holds every provider key; MIND holds none. |
| **GRAPH** | Oxigraph RDF, projected from the Rails models. BACK holds the authority. |
| **NATS** | The in-pod L7 broker (ADR 0065). JetStream on `nats-data`, unpublished. Not `ROLE=bus`. |

Implemented under `runtimes/`; reference POC is `app-osi-8-nooa-poc`.

## The adoption flywheel

**SwitchYard** (free online/offline routing) drives developer adoption →
**ThreeDot** grounds CPCP/OSI-8 calls in the editor → **MagenticMarket** offers a
marketplace for verified offers without data inspection. See `apps/` + `plugins/`.

## The ownership boundary

See [`../../GOVERNANCE.md`](../../GOVERNANCE.md). Own the language and contracts
(🟢), build the products (🔵), follow the runtimes (🟡).
