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

## The governance pod — 5-container MIND Pod

The MIND Pod separates the transient agent runtime from durable governance
surfaces so the enterprise surface stays stable while upstream churns:

| Container | Role |
|---|---|
| **FRONT** | UI + a bounded view onto MIND. The only surface users see. |
| **BACK**  | Context / Memory / the `/_cpcp` contract seam. |
| **BackJob** | Durable, asynchronous work. |
| **GRAPH** | Oxigraph RDF truth store. |
| **MIND**  | Runs the (upstream) agent in OS-level isolation. Cannot bypass evidence paths. |

Implemented under `runtimes/`; reference POC is `app-osi-8-nooa-poc`.

## The adoption flywheel

**SwitchYard** (free online/offline routing) drives developer adoption →
**ThreeDot** grounds CPCP/OSI-8 calls in the editor → **MagenticMarket** offers a
marketplace for verified offers without data inspection. See `apps/` + `plugins/`.

## The ownership boundary

See [`../../GOVERNANCE.md`](../../GOVERNANCE.md). Own the language and contracts
(🟢), build the products (🔵), follow the runtimes (🟡).
