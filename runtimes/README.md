# runtimes/  🟢 OWN IT

**The governance plane - the MIND Pod.** Separates the transient agent from the
durable governance surfaces so the enterprise surface stays stable while upstream
churns behind pinned seams.

The **canonical deploy path** is a standard **Rails 8 app + `rails_cpcp`**, which
deploys as **three containers** (one image, three roles) - plus the agent client, the LLM plane and the RDF projection. Canonical topology is six: **switch, back, backjob, front, mind, graph**.

| Box | Kind | Subdir | Role |
|---|---|---|---|
| **FRONT** | deploy container (rails_cpcp) | `mind-pod/app/` (`ROLE=front`) | The distinct front pod; talks to BACK only over JSON-RPC-LD (`/_cpcp`). |
| **BACK** | deploy container (rails_cpcp) | `mind-pod/app/` (`ROLE=back`) | The Rails app: **sole writer**, canonical store, the `/_cpcp` seam. |
| **BACKJOB** | deploy container (rails_cpcp) | `mind-pod/app/` (`ROLE=backjob`) | Durable, asynchronous work. |
| **MIND** | agent client (not a deploy container) | `mind-pod/mind/` | The **Python agent** (human + browser/AI cyborg) that points at the BACK url and reaches Effects ONLY through the seam. |
| **SWITCH** | LLM plane | `switch/` | Holds every provider key; MIND holds none. No local model ships, so the completion path egresses once a key is set. |
| **GRAPH** | RDF projection | `graph/` | Oxigraph, behind BACK. Projected from the Rails models — every node references a Rails Model, class or instance — so BACK remains the authority. In compose; projection not yet wired, so the store is empty. |

- **Reference POC:** `mind-pod/` (`app-osi-8-nooa-poc`) is a **reduced** MIND Pod:
  `app/` = **BACK** (a hand-rolled JSON-RPC-LD seam + sole-writer canonical store)
  and `mind/` = **MIND** (the Python agent client). Its `docker-compose.yml` brings
  up BACK + MIND; `app/extract/compose.yml` adds BACKJOB. The production path replaces the hand-rolled BACK with a standard
  Rails 8 app + [`../interfaces/rails-cpcp`](../interfaces/rails-cpcp/).
- **Boundary rule (enforced by Gate 1 Part C):** MIND may only produce Effects
  through BACK's shape-gated `/_cpcp` seam - never a direct write path. The runtime
  negative-test lives at [`mind-pod/test/mind_boundary_test.py`](mind-pod/test/mind_boundary_test.py).
- **Deploy:** container/orchestration lives in [`../deploy/`](../deploy/).
