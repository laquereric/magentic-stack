# mmg-switchyard (private)

**threedot's LLM-assistance plane via NVIDIA Switchyard** — for BOTH **Develop**
(syntax/coding help) and **RUN** (runtime assistance). A threedot **CID** delivers both, and
Switchyard is the key to both: threedot uses Switchyard to get LLM assistance from a **local
(MLX) or remote** source.

- **All LLM usage is wrapped in the CID Config <-> Switchyard contract** (`Config` + `Contract`).
- **local | remote** routing via `Router` (policy + trust-ladder + private-vs-portable data).
- **Every LLM call is OTEL-instrumented** (`Observe`, via `mmg-observe`).
- **Composes with `mmg-ooce`**: Switchyard is the execution plane; the OOCE `ExecutionEnvelope`
  names the route; the KV realization is a local-MLX Switchyard artifact.
- Single **MCB seam** (`Mcb::Tool`), never-raise.

Status: **scaffold** — the research + concrete design is a live Manus consult; the memo lands
in `docs/` and drives the build. LicenseRef-DataYoursSoftwareMine-1.0.
