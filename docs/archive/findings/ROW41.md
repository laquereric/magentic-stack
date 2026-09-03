# Row 41 — the CPCP `DB_PATH` effect does not exist

Measured 2026-09-03 from `521bd86`. **Design only. Not built.**

The row reads like "add a refusal." It is not. **The CPCP `DB_PATH` effect
does not exist.** So 41 is really "build the effect, with the refusal in
it" — and its sibling row 39 (the closed path set, owner = persist) is a
stated prerequisite that also does not exist. ADR
[0051](../../adr/0051-db-path-is-a-cpcp-effect.md) is `unenforced: true`,
`enforced_by: []`, stand-in the compose env that binds the path today.

No `database.yml` edit. No persist. No `.agent`. No `mind/vendor`.

---

## What is actually there

SHA `521bd86`. Ours only; `upstreams/nooa` excluded (~40 more hits,
none of them ours). Population named per count.

### Readers (consume the env var)

| Kind | Site | What it does |
|---|---|---|
| Rails ERB | `runtimes/mind-pod/app/config/database.yml:14` production | `ENV.fetch("DB_PATH", "db/mind_pod.sqlite3")` at **load** |
| Rails ERB | `database.yml:17` development | same |
| Shell | `extract/entrypoint.sh:6` | echo at start |
| Shell | `extract/entrypoint.sh:19` | BACKJOB wait-loop: `[ -f "${DB_PATH:-…}" ]` |
| Python | `runtimes/mind-pod/mind/mind_agent.py:67` | `os.environ.get("DB_PATH")` inside `_storage()` |

Population: 5 read sites, 3 kinds. Claude's 14385f0 list also named
`spec_helper.rb:2`. That line **sets** `ENV["DB_PATH"]`. The test
stanza of `database.yml:20` is the literal `"db/test.sqlite3"` and
does **not** fetch the env. Counted as a setter, not a reader.

### Setters (compose / spec)

| Site | Service / role |
|---|---|
| `docker-compose.yml:33` | back `/data/mind_pod.sqlite3` |
| `docker-compose.yml:39` | backjob same |
| `docker-compose.yml:97` | mind `/mind-data/nooa.sqlite3` |
| `extract/compose.yml:25` | back |
| `extract/compose.yml:43` | backjob |
| `extract/compose.yml:100` | mind |
| `spec_helper.rb:2` | test env, unused by `database.yml` test stanza |

Population: 6 compose bindings + 1 spec setter. FRONT / vault / config
/ shape set **no** `DB_PATH`. Persist: **no** entrypoint branch, **no**
seam_authority row. `ROLE=persist` does not exist.

### OBSERVED vs the boot-only sentence

| Claim | Mark | Code |
|---|---|---|
| Rails path is ERB at load; a change is a reconnect | **OBSERVED** | `database.yml:14,17` |
| BACKJOB consults the path only in the wait loop, then `exec` | **OBSERVED** | `entrypoint.sh:19` |
| MIND `_storage()` reads `DB_PATH` on every `build_agent` | **OBSERVED** | `mind_agent.py:67,140`; `harness.py:114` calls `build_agent` **every cognition cycle** |
| A live CPCP method can change this process's sqlite path | **absent** | no method, no persist |

Rails is boot-once. MIND is **not**: it re-reads the env each cycle and
constructs a new `SQLiteStorageManager`. That is not `establish_connection`
on a live pool; it *would* follow a mutated env without a restart. Docker
does not mutate env of a running container. Named so row 41 does not
inherit a false "all consumers are boot-only."

---

## SPECIFIED (narrow)

These are MUST because row 41 / 0051 already said so, not because the
Ruby does them (it does not).

| # | SPECIFIED |
|---|---|
| S1 | There is no live swap. An effect that would change the path of a **running** process is refused. Refusing is the contract. |
| S2 | A path change is a restart. After restart, ERB / entrypoint / MIND bind the new env. No operation spans the swap. |
| S3 | No dual write of domain state. Old store is not written as part of the swap. Avoids the only operation that would write two domain stores (row 20 / 0056). |
| S4 | The parameter, **when a path is accepted for a future boot**, is a closed set (row 39), not a free-form string (0051 §1). |

Not SPECIFIED here: method name, who may call, persist-for-every-store
(row 48 — decided, unbuilt, not reopened).

---

## 1. What the effect is

0051: control of `DB_PATH` for SQLite in MIND and every Rails container
moves to `/_cpcp` effects. No method is named.

| | BACK | persist |
|---|---|---|
| Exists today | Yes. Live CPCP `POST /_cpcp/rpc`. | **No.** No ROLE, no routes, no seam. |
| Charter | Domain writer (0056). Journal lives here (0052/73). | Write-LOCATION, closed path set (row 8, 39, 48). |
| Can refuse a live swap of *this* process | Yes, if we add a method. | N/A until it exists. |
| Can change another container's env (MIND, BACKJOB) | **No.** | **No**, not by magic; only by recording next-boot placement those processes read **at start**. |
| Can hold the closed set | Would duplicate persist. | That is the job. |

**Argument:** placement is persist's charter. BACK serving "where the
sqlite lives" would make the domain writer the placement authority,
which row 8 forbade. Until persist exists, **there is no honest
server for the 0051 effect.**

A candidate name, not a decision: `persist.path.set` on `ROLE=persist`,
params `{ "path": <closed-set member>, "store": "domain"\|"mind"\|… }`,
caller allowlisted (0051: "named caller with an explicit operation").
Not minted as a BACK method in this document.

---

## 2. How a refusal is reachable

Rails reads `DB_PATH` at load. There is no running setter. A CPCP
method on BACK cannot `establish_connection` without becoming the live
swap row 41 forbade.

So a "refuse live swap" method on BACK is reachable **and would always
refuse** (except a no-op when the requested path equals the current
env). It would not move control off compose. Compose still wins at
next boot.

The 0051 effect — *where a container writes stops being a deploy-time
constant* — needs a record of **next-boot placement** that is **not
inside the sqlite being left**. That record is persist's. Persist does
not exist.

**Finding, not a failure: the 0051 effect cannot be built before
persist.** A BACK method that only refuses is a stake in the ground,
not the effect. Shipping it under the name of the effect would be a
false SPECIFIED.

---

## 3. "Require a restart" for three kinds

| Kind | What restart means | Who restarts it |
|---|---|---|
| Rails (BACK, BACKJOB) | Kill the process; entrypoint runs; ERB re-evaluates; BACKJOB's wait loop looks for the new file. | Orchestration (compose), not CPCP. |
| Shell | The wait loop does not re-read after `exec`. Restart is a new entrypoint. | Same. |
| MIND | New container/process; `_storage()` sees the new env. (Today it also re-reads every cycle; a restart is still the honest control.) | Same. MIND has no inbound `/_cpcp` (row 10 unbuilt). |

No CPCP method in this tree can restart a sibling container. The
effect records intent; **restart is operational**, outside the RPC.

---

## 4. Row 39 — closed set first, or refuse against an open set?

| Half of 41 | Needs row 39? |
|---|---|
| Refuse a live swap (path is not applied) | **No.** The string is not written anywhere that becomes a store. |
| Accept a path for the *next* boot | **Yes.** 0051 §1: a free-form path is an arbitrary-file-write primitive. "Validated with a regex" is not a closed set. |

Building the refusal half against an open set is safe only if the
path is never stored as placement. The moment we persist "next boot
use `/vault/secrets.json`" we have skipped 39.

**The effect that 0051 named needs 39 first. The refusal-only stake
does not, and is not the effect.**

---

## 5. Continuity after row 17

Row 41 dissolved the bootstrap paradox: old store keeps pre-swap
history, new store gets a boot receipt, continuity from **the event
log**, no dual write.

Row 17 then **declined** `rails_event_store`. The load-bearing event
log is BACK's operation journal, **inside the domain sqlite**. Moving
`DB_PATH` leaves that journal in the file we walked away from.

So "continuity comes from the event log" currently names a log that
**does not survive the move**. That is not a reason to reopen live-swap
or dual-write. It **is** a reason persist must hold placement (and any
boot receipt pointer) **outside** the sqlite being left. Without
persist, the dissolution is incomplete.

---

## 6. What 0051 `unenforced_because` becomes

Today: `"DB_PATH as a CPCP effect is accepted and unbuilt (row 39);
stand-in is the compose env…"`. Whole unenforced (`enforced_by: []`).

| Option | `unenforced_because` |
|---|---|
| Wait for persist (recommended) | Still whole. Name persist (row 8) **and** row 39. Compose stays stand_in. |
| BACK refusal-only now | Would become **partial** if a checker gated the always-refuse method — and that would **fake-enforce** 0051's control plane. Do not. |
| Accept paths against an open set | Forbidden by 0051 §1. Do not. |

---

## 7. Owner decisions this document will not take

| Decision | Why it is not mine |
|---|---|
| Build `ROLE=persist` | Row 8, unbuilt. |
| Whether persist owns placement for **every** store | Row 48, decided-unbuilt. Not reopened. |
| The closed path set's contents | Row 39, owner = persist. |
| Method name / who may call | 0051 left caller open. |
| Restart orchestration (compose vs an effect that kills siblings) | Not a CPCP question we were asked to mint. |

---

## 8. Recommendation

**Do not build 41 as a BACK method this turn, or next, until persist
exists.** Say the row's true size: the effect is unbuilt, the closed
set is unbuilt, the server ROLE is unbuilt. A refusal without those
is not 0051.

When persist exists: it serves the effect, holds the closed set
(covering domain sqlite, MIND NOOA, and whatever 48 named), refuses
live swap, records next-boot placement **outside** the file being
left, and a restart is how Rails ERB / entrypoint / MIND bind it.
0051 stays `unenforced: true` until that is gated.

---

## 9. What this is not

- Not the effect. Not a method. Not a `database.yml` change.
- Not row 40's boot-only *gate* (that row is still open; MIND's
  per-cycle `_storage()` is a fact it should see).
- Not persist. Not the closed set. Not row 11. Not the 0050 amendment
  (queued after this doc).
