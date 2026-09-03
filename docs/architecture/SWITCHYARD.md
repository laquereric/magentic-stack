# ROLE=switch → SwitchYard — surface design (row 11)

Measured 2026-09-02 from `a08c101` / pin `47babb1`. **v1 built 2026-09-03**
(Shape D: Node reverse-fronts `/v1/*` to `switchyard-server` at pin
`47babb1`, algorithms `noop` / `passthrough` / `random` only). Host-published
data-plane port: still none. UI `:13001` retired (row 11 slice C).

ADR [0050](../adr/0050-switchyard-is-the-upstream-plus-bus-and-persist-roles.md)
already decided we consume NVIDIA Switchyard and do not write our own
router. This document is the surface 0050 said had to be designed against
the Node service that actually runs, the pin that actually sits in
`upstreams/`, and the decisions that landed after 0050 (rows 15, 18, 19,
83, 84).

No Dockerfiles, no compose ports, no adapters, no gem changes in this
change.

---

## What is actually there (so the table is not a wish)

| Thing | Measured |
|---|---|
| Process compose starts | **`node server.mjs`.** Image `mind-pod-switch`. Dockerfile `FROM node:20-slim@sha256:2cf0…`. |
| NVIDIA binary | **pinned, unused.** Submodule `upstreams/nemo-switchyard/src` at `47babb1a933e952bc6997b9ea208b5903c61a48c`. Default listen **4000**. Credentials from **env vars** named in TOML (`NVIDIA_API_KEY`, …), not `/state`. |
| Runtime `.mjs` | **8 files, 1129 lines.** `server.mjs` is still **350**. Tests: 8 more `.mjs`. The row's "17 `.mjs`" is stale (16 `.mjs` in the tree including tests; 8 of those are tests). |
| Data plane | `:8789` unpublished. `POST /v1/chat/completions`, `POST /v1/messages`, `GET /health`. MIND calls `http://switch:8789/v1`. Rejects `Origin`. |
| UI plane | `:8790` pod-internal for config-admin's display (host `:13001` retired, row 11 slice C). `/`, `/api/sources`, `/api/refresh` (discovery), `/api/verify-tools`, `/api/test`. |
| Catalog table | **already gone from this tree.** `llm_catalog.json` is owned by `ROLE=config`. `catalog.mjs` is 56 lines of routing helpers and loads that JSON (row 15 / gap 108). |
| Discovery / verify | **still here**, credential-bearing, billed verify on demand never automatic (row 15, gap 108). |
| Keys | vault slots `switchyard.<vendor>` (row 11 slice A); the `/state` bind mount keeps non-key routing state only. Row 46: convert **neither** bind mount. |
| Language | named **violation**, not exemption: observed Node, target Rust (`language_rule.json`). |
| Seam | `runtimes/switch` is **not_a_seam**. Live sibling is `switchyard-offline` (local credential routing). |
| Adapters | `gems/adapters/` is one README. ADR 0038: sole path to upstreams. |
| Content rule | **ADR 0019**: routing reads headers (`X-SwitchYard-Source`), never the body. |
| NVIDIA routing | at this pin, algorithms **do inspect request content** (escalation / judge). Opposite of 0019. |
| Cache-attest | **nothing.** Row 83/84 are decided and unbuilt. "cached" hits in the pin are token counters, not an admission contract. |

The 8 runtime files are the only Node bytes a replacement has to tell the
truth about. The pin is real Rust and is not what the pod runs.

---

## 1. 0050's list, scoped against what runs and what is pinned

0050:1 — `switch` contains ONLY NVIDIA Switchyard plus a `/_cpcp/rpc`
endpoint. Rows 15 / 18 / 83 grew the charter after that sentence.

| 0050 / later item | From Node today? | From the pin today? | Needs building? | What it even means |
|---|---|---|---|---|
| **Data-plane proxy** (OpenAI Chat / Anthropic Messages / OpenAI Responses) | Yes. `server.mjs` + `translate.mjs` + `providers.mjs`. | Yes. That is what `switchyard-server` is. Default `:4000`. | A cut-over. Not a new protocol. | Established: MIND keeps speaking `/v1` at `http://switch:8789/v1`. |
| **Routing** | Yes. `router.mjs`, content-blind, header pin (0019). | Yes, **and it is not content-blind.** Judge / escalation read the prompt. Random / passthrough exist. | A **config choice**, or an 0019 amendment. | See §3. This document does not amend 0019. |
| **`/_cpcp/rpc` on this container** | No. Switch is not_a_seam. | No. | **No, on this container.** Row 18 decided Rails `ROLE=bus`, Rust does pure proxying, no fork, no fourteenth container. | Established as *not this process*. The 0050 title's "plus a CPCP endpoint" is the bus, not a method on `switchyard-server`. |
| **Catalogue table** | Helpers only. | Not described. | Already on `ROLE=config` (row 15). | Display. Not this job. |
| **Discovery** (which models a key opens) | Yes. `discovery.mjs` 78 lines; credential via vault fetch. | **Not described.** | Must stay with the credential holder. Not `ROLE=config` (no `get`). | Router charter (row 15). Dropping it is a FAIL of that charter. |
| **Verify** (tool support, billed, on demand) | Yes. `verify.mjs` 77 lines; uses `complete`. | **Not described.** | Same as discovery. | Never automatic. |
| **Keys / sources** | `/state` bind mount. | Env vars. | Bridging is adapter work. Do not convert the bind mount (row 46). Do not touch `.agent/secrets` in the scope. | 0050 *targets* vault; v1 need not move the store. |
| **UI `:13001`** | Retired (row 11 slice C). | Not an upstream feature. | Was `config-admin`; display now lives there. | No replacement host port (gap 61). |
| **Cache reuse attest** (row 83) | No. | No admission contract. | Yes, and it is **new**. | Supply what can be attested; **refuse** reuse otherwise. Do not guess. |
| **Pre-alpha pin** (row 19) | n/a | README:27,30: pre-alpha; *Experimental software. Not for production use.* Pin `47babb1`. | Gate: pin cannot move without recorded re-review. ADR quoting upstream wording is decided-unbuilt. | Accepted risk. The Node service works today. |

**v1 is the unpublished data-plane cut-over to the pin, content-blind
algorithm only, with discovery/verify still executing where the keys
are.** The UI move, the vault key move, the bus CPCP endpoint, and a
real cache-admission contract are not padded into a surface that sounds
finished.

---

## 2. One container, or a fourteenth?

Target is **12 containers, 4 images** (nine Rails ROLEs + MIND +
SwitchYard + oxigraph). Today is nine. `bus` and `persist` are the
remaining two Rails ROLEs. Replacing Node with NVIDIA is a rename of
`switch`, not a new row in the compose file.

| | What | Cost |
|---|---|---|
| **A. NVIDIA *beside* Node** | New compose service. Node keeps UI + discovery + verify. | 10th running container now; 13 after bus+persist. Breaks the 12. **Reject.** |
| **B. Two processes, one `switch` service** | `switchyard-server` on the data port; Node leftover on `:8790` for UI / discovery / verify. | One compose service, mixed image, language gate still sees Node if that is the image. Operationally ugly. Survivable as a *migration* shape, not as the target. |
| **C. NVIDIA *replaces* `CMD node server.mjs`** | Data plane is the pin. Discovery / verify / UI must live in this same replacement or they vanish. | Vanishing is a FAIL of row 15. So C is only legal once those three have a non-Node home in the same service (adapter) or on an already-counted ROLE. |
| **D. Node stays, forwards `/v1/*` to NVIDIA, stops routing** | Our `router.mjs` dies. NVIDIA routes (content-blind config). Node is UI + keys + discovery + verify + reverse-front. `.rs` count stays 0. Language **violation remains** until Node is deleted. | Honest about 15 and 18. Slow to clear row 12. **This is v1.** |

**v1 takes D.** Consuming the upstream does not require deleting the
charter extras on the same day. Rewriting Node to Rust *to make the
language gate pass* is still forbidden (gap 12). The violation goes
away when Node is gone, not when it wraps a Rust binary.

A later increment (not v1) is C: leftover Node deleted after UI is
config-display and discovery/verify execute as `gems/adapters` against
the same credentials the proxy uses.

---

## 3. ADR 0019 vs the pin (do not silently pick)

0019 is accepted and gated: the pod router is **content-blind**. The pin
at `47babb1` ships judge / escalation algorithms that **read the
prompt**. Random / passthrough exist on the same binary.

| | What | Cost |
|---|---|---|
| **A. Content-blind config only** (v1) | Run `switchyard-server` with passthrough / random / header pin. Do not enable judge or escalation. 0019 stands. 0050's "consume" stands. | We do not get NVIDIA's headline routing. We do get translation + multi-backend proxy, which is what MIND actually needs. **This is v1.** |
| **B. Enable judge / escalation** | Amend 0019. A router that reads the prompt has read the prompt. | Owner decision. This document does not take it. |
| **C. Run the pin as-is with whatever the sample TOML enables** | Silent 0019 break. | Forbidden. Absence of a config is not a decision. |

**v1 takes A - and as of 2026-09-03 this is an OWNER RULING, not this
document's recommendation: routing is content-blind.** ADR 0019 stands
unamended. The pin's judge and escalation algorithms are not enabled, at v1
or later, without a new decision that supersedes this one. "Consume NVIDIA"
is not "turn on every algorithm in the README."

Pinning stays a header (`X-SwitchYard-Source`), not the body's `model`
field, for *our* leftover Node. What the pin's own config uses for a
sticky route is adapter work; it must not become "parse the prompt."

---

## 4. Discovery, verify, keys, UI

Gap 108 already split these by credential need. Do not re-derive it.

| Module | v1 | Later |
|---|---|---|
| `catalog.mjs` helpers | Stay with whoever routes. Table stays `ROLE=config`. | — |
| `discovery.mjs` | Still executes on the credential holder (Node leftover under D). | Adapter next to the proxy, or an effect the holder exposes so config can *display* results. Not `ROLE=config` execute. No new config-to-switch probe RPC (gap 108). |
| `verify.mjs` | Same. On demand, billed, never automatic. | Same. |
| Keys | Existing `.agent/secrets:/state` bind mount for non-key routing state. Keys moved to vault slots `switchyard.<vendor>` (row 11 slice A; `llm-plane` may `get`). Row 46 still forbids converting the bind mount to a volume or sqlite. Do not touch `.agent/secrets` in the scope. |
| UI `:13001` | Retired once config-admin showed sources + test results (row 11 slices B–C). | Retired. **No new host port** (gap 61). Data plane stays unpublished. NVIDIA's `:4000` is internal remap onto 8789. |

0046 already permits the UI to show test results, never a value.
Executing discovery/verify is still the holder's job.

---

## 5. Row 83 / 84 — refuse reuse you cannot attest

Decided: the router owns reuse; a block may be consumed only if its
recorded execution identity matches; mismatch is a refusal. The identity
components Manus listed (weights, tokenizer, chat template, sampling
config, adapter, cache format) are **still not established**.

The pin does not ship that contract. Token "cached" counters are not
admission.

**v1 therefore has no cache to reuse.** The honest implementation is:
do not reuse; do not invent an attest surface that reports ok on
guesses. A later increment that *does* reuse must refuse anything it
cannot attest. Do not let "the router owns it" become "the router
guesses."

This is charter on the build, not a v1 endpoint.

---

## 6. What building v1 would touch (not done here)

When an implementation brief exists, and not before:

- `gems/adapters/` — the only place we are allowed to wrap the pin
  (ADR 0038). Today a README. This is where env-injection, port remap
  4000→8789, and content-blind algorithm config live. Not a fork of
  `upstreams/nemo-switchyard/src`.
- `runtimes/switch/server.mjs` — `/v1/*` forwards to the pin; routing
  via `router.mjs` stops being the data-plane decision.
- Compose: same `switch` service, still unpublished 8789, still
  published 8790 until the UI moves. **No new ports.** Optionally start
  `switchyard-server` in-process/sidecar of that one service (shape B)
  behind the Node reverse-front (shape D).
- Row 19 gate: pin cannot move without recorded re-review. The quoting
  ADR is decided-unbuilt and is **not this document**.
- `language_rule.json` — violation remains until Node is gone. Do not
  convert it to an exemption. Do not rewrite Node to Rust to clear it.

Gap 23, vault inbound, dual-v1, and Python urlopen (row 104) are not
this job. Row 104 is queued behind this scope, not concurrent.

---

## 7. Owner decisions this document will not take

| Decision | Why it is not mine |
|---|---|
| ~~Enable NVIDIA judge / escalation (amend 0019)~~ | **TAKEN 2026-09-03: NO. Routing is content-blind.** 0019 stands unamended; v1 option A is now the owner ruling, not this document’s recommendation. Judge and escalation stay off |
| Move keys into vault | 0050 target; row 46 bind-mount form; not v1 |
| Host-published port for the replacement | gap 61; delegation said no port yet |
| Write the row-19 quoting ADR + pin-move gate | decided-unbuilt; sibling of this build |
| Build `ROLE=bus` `/_cpcp/rpc` | row 18, row 9 blocked on 17 |
| Invent a config-to-switch discovery RPC | gap 108; new seam |
| Fourteenth container | row 18; 12-container target |
| Rewrite Node to Rust to pass the language gate | gap 12 |
| Establish the row-83 identity component list | still not established; refuse, don't guess |
| Touch `.agent/secrets` | standing |

The consume-vs-rewrite call **was** asked for. 0050 already answered:
consume. This document answers *how* to consume without breaking 0019,
15, 18, or the 12-container count.

---

## 8. What this is not

- Not a build. Not a port. Not a compose service.
- Not a fork of NVIDIA Switchyard.
- Not a claim that the pin is content-blind.
- Not a claim that discovery/verify live in the pin (they do not).
- Retired `:13001` after config replaced the display (row 11 slice C).
- Not row 104 (Python `urlopen` discards the envelope). That is queued.
- Not `switchyard-offline` (Chrome MV3, a different live seam).
