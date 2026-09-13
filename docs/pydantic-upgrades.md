# Pydantic-org upgrades for magentic-stack

Evaluated 2026-09-13 against the pydantic GitHub org, NOOA at
`8b3c719`, and the twelve-container pod. This is the implementation
contract. Do not adopt pydantic-ai as a second agent runtime inside
MIND.

Worktree: `grok/pydantic-upgrades` at
`copilot-worktrees/magentic-stack-pydantic-upgrades`.

---

## What is already true

`runtimes/mind-pod/mind/mind_agent.py` already does
`from pydantic import BaseModel, Field`. The MIND→BACK proposal
shapes (`NoteInsight`, `BoardReading`, `SessionReading`) are pydantic
models. `tooling/linkml` already generates a pydantic face. **Pydantic
is load-bearing.** It was arriving as a transitive of NOOA
(`pydantic>=2.5.0`) with `requirements.txt` containing only comments.

NOOA and pydantic-ai overlap on the contract (typed I/O) and diverge
on isolation. That is where the value is.

---

## Adopt

### 1. Pin pydantic explicitly — **this branch, gated**

A dependency that determines the proposal shape cannot be a
transitive accident under "pinned, never forked."

- `upstreams/manifests/pydantic.pin.json` (`kind: pypi`, not a
  git submodule — Gate 1/4 learn that distinction here)
- `runtimes/mind-pod/mind/requirements.txt` declares `pydantic==2.13.5`
- the MIND Dockerfile installs that file *and* the vendored NOOA
- `tooling/pins/check_pydantic_pin.py` + plant + CI workflow

Do not add `upstreams/pydantic/` as a directory. Gate 1 still
requires `upstreams/<name>/` = README + `src/` submodule. A PyPI pin
lives in `manifests/` with `kind: pypi`.

### 2. Monty as the CodeAct isolation seam — **gitlink + adapter + wheel in the image**

NOOA CodeAct is "a linter, not a sandbox." Distroless removes the
shell, not `open()` / `socket` / `os.environ` inside the interpreter.
Monty is a Rust Python-subset VM: no fs/env/network except what you
pass in. That is a CPCP Effect surface.

- ADR 0070, gitlink `upstreams/monty/src` @ `adc986b3…`
- `gems/adapters/monty/run.py` never-raise; CPython is not a fallback
- MIND `mind_codeact.install` intercepts `execute_python` and does
  not call `nxt`
- `pydantic-monty==0.0.23` in MIND `requirements.txt`; `MONTY_BIN=/deps/bin/monty`
- `mind/bin/prepare` copies the adapter onto the image `PYTHONPATH`
- checker + plant + `gate-monty-pin`

Do not replace NOOA. The intercept is live in the image. A cell that
uses an unsupported construct is a typed refusal, not a CPython
fallback.

### 3. genai-prices as SWITCH's pricing source — **pin + comment**

`catalog.mjs` already says prices are INDICATIVE. genai-prices is MIT
data (~1,000 models). This branch records the pin and holds the
comment; it does **not** vendor `data.json` or take ownership of
`llm_catalog.json` away from ROLE=config.

Refresh of overlay data is a later slice. The gate is: the catalog
still admits INDICATIVE, and the pin file exists.

### 4. OTel GenAI semantic conventions. Not Logfire.

LOG is the thirteenth container (ADR 0058). Logfire's SDK is MIT; its
**server is closed source** and self-hosting is a paid license. The
governance plane cannot depend on that backend.

- ADR 0058 now says Logfire is an optional OTLP *sink*, never a
  dependency
- `tooling/pins/check_no_logfire.py` fails if `runtimes/` imports it

Emitting GenAI-semconv spans at `/_cpcp` and SWITCH is the next
slice. This branch only closes the door.

### 5. Cite pydantic-ai-harness in ADR 0001. Do not vendor it.

External validation of OWN/FOLLOW: they split the harness out of
pydantic-ai so capabilities can churn while the framework stays lean.
The code itself (shell, browser, filesystem, sub-agents) would blow
through the bounded Effect surface.

### 6. NOOA vendor is a plant from the pin, not a second home

`mind/bin/prepare` already copies `upstreams/nooa/src` into
gitignored `vendor/nooa/`. The gate is that it keeps doing that:
default `SRC` must be the pin's `submodule_path`, and
`/vendor/nooa/` stays gitignored.

---

## Do not adopt

| Thing | Why |
|---|---|
| pydantic-ai as MIND's agent runtime | Second cognition abstraction beside NOOA breaks the one-runtime premise of the pod |
| FastUI | Dormant since Apr 2026 |
| pydantic-ai-gateway | Archived Mar 2026 into Logfire; was AGPL |
| Logfire server | Closed source; paid self-host |

---

## Pin-risk note

The org's satellite mortality (gateway archived in ~6 months; FastUI
dormant at 8.9k stars) is why this concentrates on the durable core
(#1), data rather than code (#3), and a convention rather than a
product (#4). Only monty carries real pin risk, which is why it is
behind an adapter with its own ADR — the same treatment Switchyard
got in ADR 0061.
