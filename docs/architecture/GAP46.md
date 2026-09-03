# Gap 46: named volumes everywhere does not apply to the credential stores

Analysis only. Did not convert a mount. Did not touch, read, print, copy,
move, or list the contents of `.agent/vault` or `.agent/secrets`. No
migration script.

Claude measured the remaining scope (gap 113): three named volumes already
exist; two bind mounts remain, and both are credentials. This document
answers the four questions that measurement opened.

## 1. What virtiofs actually costs here

NOOA's `_is_virtiofs` (`upstreams/nooa/src/src/nooa/storage/sqlite.py`)
detects Docker Desktop file sharing because **SQLite** misbehaves on it
(locks, WAL/SHM, readers holding shared locks). The compose comments on
`mind-nooa-data` say the same thing.

Neither credential store is SQLite.

| store | path in container | on-disk form | writer |
|---|---|---|---|
| vault | `/vault/secrets.json` (`VAULT_STORE_PATH`) | one encrypted JSON file; persist is tmp + chmod 0600 + rename | `Vault::Store` |
| switch | `/state/sources.json` (`SWITCH_STATE_DIR` + `sources.json`) | one JSON file (`keys`, `enabled`, `prices`, `discovered`, `verified`) | `sources.mjs` `saveState` |

No `db`/`-wal`/`-shm` triple. No SQLite lock. The virtiofs hazard that
justified named volumes for `mind-data` and `mind-nooa-data` **does not
apply**. Converting these two binds because "SQLite on virtiofs" would
be solving a problem they do not have.

The SQLite half of row 46 is already done.

## 2. What `down -v` actually costs

`docker compose down -v` removes **named volumes**. Bind mounts are host
paths and survive. Today:

| volume | type | survives `down -v` | intended? |
|---|---|---|---|
| `mind-data` | named | no | yes — domain sqlite |
| `mind-nooa-data` | named | no | yes — agent memory is not a credential |
| `graph-data` | named | no | yes — projection |
| `.agent/vault` | bind | **yes** | ADR 0046:85 |
| `.agent/secrets` | bind | **yes** | same, switch comment |

Compose env (`VAULT_MASTER_KEY`, `VAULT_CALLERS`, `CONFIG_VAULT_TOKEN`,
`SECRET_KEY_BASE`, …) is not a volume. `down -v` does not unset it.

If both binds became named volumes, `down -v` would add two losses:

**Vault slots.** Names are operator-chosen (`Vault::Store::NAME_RE`),
unbounded. They are **not** the vendor keys (gap 108: those were never
in vault). Occupancy was not counted: the brief forbids reading the
store. Re-placement is `ROLE=config` `PUT /secrets` at `:13003`, one
put per slot, values from the operator's own records. Config-admin
cannot read a value back. Destroyed values are not recoverable from
the pod. `VAULT_MASTER_KEY` remaining in env does not recover a
deleted `secrets.json`.

**Switch slots.** Remote catalog vendors that take a key:

- `openai`
- `anthropic`
- `fireworks`
- `openrouter`
- `nvidia`

Six key slots (`openai`, `anthropic`, `fireworks`, `openrouter`, `nvidia`,
`meta`). `ollama` is local and needs `OLLAMA_URL`, not a key.
`sources.json` also holds `enabled`, `prices`, `discovered`, `verified`
— converting `/state` loses routing evidence as well as tokens.
Re-placement is the vault UI at `:13003` (slots `switchyard.<vendor>`,
row 11 slice A). Values are not recoverable
from the pod. Live occupancy was not counted.

One UI, two stores, one replacement path each, both through `:13003`.
Keys are placed by the
operator, never by an agent. Recovery is manual, after a command people
run without thinking.

## 3. Options

**A. Convert both, amend ADR 0046:85.** One mount type. `down -v`
destroys every credential plus switch routing evidence. Recovery is
operator re-entry on two UIs. The virtiofs/SQLite reason does not
apply. This spends 0046's durability for a uniformity that the data
stores already have.

**B. Convert neither. Amend row 46: credential stores are the
exception.** Named volumes for SQLite/data (done). Bind mounts for
credentials (0046:85 stands). Two mount types, one rule: sqlite/data
named; secrets bind. This is what the tree already is.

**C. Convert one.** They do not differ on SQLite (neither is). They
differ in payload (encrypted operator names vs plaintext vendor keys)
but both are credentials. Converting one still breaks 0046:85 for that
store and does not simplify the mount story.

**D. A third mount.** Docker secrets / an external manager is a new
seam, not a compose edit. Copy-into-named-volume at start is a
migration of secret contents, which this turn forbids. A host path
that is not virtiofs **is the current bind mount**.

## 4. Recommendation

**B. Convert neither. Amend row 46 rather than implement it.**

The decision was made when the scope looked like "every store, because
SQLite". Measurement: SQLite is already on named volumes; the remainder
is two JSON credential files whose reason for being binds is exactly
`down -v` survival. Implementing "everywhere" now would take the one
property ADR 0046 paid for and give nothing the virtiofs detector
cares about.

Do not amend 0046:85. Amend row 46 to: named volumes for the file
triple and for agent memory (done); credential stores stay bind
mounts.

## Gate

`check_credential_bind_mounts.py` holds 0046:85 until the owner
amends: both composes bind `.agent/vault` and `.agent/secrets`; vault
path is `secrets.json`; switch state is `sources.json`; `Vault::Store`
is JSON not SQLite. Plants: vault bind converted to a named volume;
store path becomes sqlite; 0046:85 dropped.

Did not convert. Did not touch `.agent/*` contents. Did not start row 22.
