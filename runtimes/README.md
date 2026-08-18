# runtimes/  🟢 OWN IT

**The governance plane — the 5-container MIND Pod.** Separates the transient agent
runtime from durable governance surfaces so the enterprise surface stays stable
while upstream churns behind pinned seams.

| Container | Subdir | Role |
|---|---|---|
| **FRONT** | `front/` | UI and a bounded view onto MIND. The only surface users see. |
| **BACK** | `back/` | Context / Memory / the `/_cpcp` contract seam. |
| **BackJob** | `backjob/` | Durable, asynchronous work. |
| **GRAPH** | `graph/` | Oxigraph RDF truth store. |
| **MIND** | `mind-pod/` | Runs the (upstream) agent in OS-level isolation. Cannot bypass evidence paths. |

- **Reference POC:** `app-osi-8-nooa-poc` (MIND runs NVIDIA NOOA in isolation).
- **Deploy:** container/orchestration lives in [`../deploy/`](../deploy/).
- **Boundary rule:** MIND may only produce Effects through BACK's `/_cpcp` seam;
  the pod ships with boundary defaults on and testable upgrade/rollback.

## Vendored source

- `mind-pod/` is vendored in via **git subtree** (ADR 0002) — the MIND POC
  (`app-osi-8-nooa-poc`, made public 2026-08-18): a `docker-compose.yml` with a
  Rails **BACK** and a Python **FRONT**, plus feasibility/design docs. This is the
  runnable topology that **Gate 1 Part C** (the full MIND->sink runtime
  negative-test) will exercise.
