# Source status — provenance ledger

**This repo is CLOSED (ADR 0038).** Every area below lives here and nowhere else.
The "Origin" column is *history* — where the code came from before consolidation —
not a place to look for the current version, and not a place to edit.

The standalone repos named as origins were **archived 2026-08-27**. Archived
repos stay readable and cloneable, so old links and old pins still resolve; they
accept no writes. If you find yourself editing one, you are in the wrong tree.

Only `upstreams/` is genuinely external, and only those are still tracked.

## Owned areas — origin archived, this tree is the source

| Area | Origin (archived) | Consolidated |
|---|---|---|
| `grammar/osi-level-8` | laquereric/osi-level-8 | spec prose; profile shapes live in `gems/osi-level-8-profiles` — see ADR 0022 |
| `gems/osi-level-8-profiles` | laquereric/osi-level-8-profiles | 45 SHACL shapes; Gate 2 validates every profile |
| `gems/rails-cpcp` | laquereric/rails-cpcp | root path-gem; Gate 1 Part B seam specs |
| `gems/rails-osi-level-8` | laquereric/rails-osi-level-8 | root path-gem; specs in `bin/spec-all` |
| `gems/mmg-acia` | laquereric/mmg-acia | root path-gem; two harnesses (AR-free + AR) |
| `gems/mmg-acia-crud` | laquereric/mmg-acia-crud | root path-gem |
| `gems/mmg-blob` | laquereric/mmg-blob | root path-gem; depends on `vv-blob` |
| `gems/mmg-semantic-editor` | laquereric/mmg-semantic-editor | root path-gem |
| `gems/vv-base` | laquereric/vv-base | root path-gem; Actor/Persona/Journey/Flow/Mission/Vision |
| `gems/vv-blob` | laquereric/vv-blob | root path-gem |
| `gems/vv-graph` | laquereric/vv-graph | root path-gem; largest suite in the tree |
| `gems/vv-html-components` | laquereric/vv-html-components | root path-gem |
| `gems/switchyard-offline` | laquereric/app-switchyard-offline | Apache-2.0; Gate 5 offline boundary |
| `tooling/docker-swap` | laquereric/vv-docker-swap | root path-gem |
| `tooling/slo` | laquereric/vv-slo | root path-gem |
| `runtimes/effect-plane` | laquereric/mmg-effect-plane | root path-gem |
| `runtimes/mind-pod` | laquereric/app-osi-8-nooa-poc | container app; Gate 1 Part C brings it up under docker |

## Native to this repo

| Area | Notes |
|---|---|
| `gems/mmg-adr` | ADR-as-spec: decision → constraint → code. No standalone ever existed |
| `grammar/cpcp` | CPCP normative spec (scaffold) |

## Upstreams — genuinely external, pinned, never forked

| Area | Upstream | Method |
|---|---|---|
| `upstreams/nooa` | NVIDIA-NeMo/labs-OO-Agents | submodule (pinned) |
| `upstreams/nemo-switchyard` | NVIDIA-NeMo/Switchyard | submodule (pinned) |
| `upstreams/json-rpc-ld` | laquereric/json-rpc-ld | submodule (pinned; spec only, nothing executes) |

## Uncoupled products — NOT vendored here

`app-switchyard-online` (switchyard.online) and MagenticMarket are standalone
products that interoperate over CPCP. They are **not** part of this repo and were
not archived. The Gate 3 offer contract is not currently vendored here (`apps/` does not exist).

---

**Enforcement.** `tooling/boundary/check_closed.py` asserts no gemspec points at
a `laquereric/` repo other than `magentic-stack`, no vendored directory contains
a nested `.git`, `.gitmodules` lists only the three upstreams above, and every
gemspec'd component appears in the root `Gemfile`. It fails closed. `bin/spec-all`
runs every suite and fails if it finds none.
