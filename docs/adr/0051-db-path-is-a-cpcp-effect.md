---
id: "0051"
title: DB_PATH is controlled through CPCP effects, not deploy configuration
subject_kind: protocol
subject: sqlite binding
status: accepted
date: 2026-08-31
components: [back, backjob, front, vault, config-admin, shape, project-graph, persist, bus, mind]
paths:
  - runtimes/mind-pod/app/config/database.yml
  - runtimes/mind-pod/mind
enforced_by: []
supersedes: null
superseded_by: null
---

# DB_PATH is a CPCP effect

## Decision

**Control of `DB_PATH` for SQLite -- in MIND and in every Rails container --
moves to `/_cpcp` effects.** Where a container writes its database stops being a
deploy-time constant and becomes a governed operation: admitted through a shape,
carrying an `operationId`, producing a receipt.

This is coherent with Flexible Determinism: storage location becomes an
explicit, auditable fact at the deterministic plane instead of a property of
whoever last edited compose.

## What it changes

Today `DB_PATH` is read **once, at boot**:

    # config/database.yml
    database: <%= ENV.fetch("DB_PATH", "db/mind_pod.sqlite3") %>

ERB evaluates when the configuration loads. Consumers: `database.yml`,
`spec_helper.rb`, `extract/entrypoint.sh` (twice -- including the backjob wait
loop), and both compose files.

## Five things that must be settled, or this is dangerous

### 1. Unless the paths are closed, this is an arbitrary-file-write primitive

An effect that decides where a process writes its database can point a
container outside its volume, at another container's database, or at a bind
mount -- including the one holding vault secrets.

**The parameter must be a closed set, not a string.** A shape with `sh:in` over
an enumerated list of permitted paths, refused at admission the way the vault
allowlist refuses an operation. A free-form path parameter is the failure mode,
and "validated with a regex" is not a closed set.

### 2. Rails resolves the database at boot; changing it is a reconnect

A runtime change means `establish_connection` -- dropping the pool, abandoning
in-flight transactions and prepared statements. This is **not a setter**. It is
**quiesce, swap, resume**, and the behaviour of a request in flight during the
swap must be defined rather than discovered.

### 3. The bootstrap paradox

CPCP admission records operations **in the database**. The operation that
*changes* the database therefore has nowhere obvious to be recorded: the old
store is the one being left, and the new one may not exist yet.

If the receipt lands only in the old store, the new store has no record of its
own origin. If only in the new one, the old store's history ends without
explanation. **Both, linked by one `operationId`** -- "we left" in the old,
"we arrived" in the new -- is the only version where the audit chain survives
the interesting moment. Anything else breaks the chain exactly where a reader
would most want it.

### 4. MIND has no database

Zero `DB_PATH` consumers in Python. `harness.py` is stdlib `urllib` + NOOA and
holds no state. "Control `DB_PATH` in MIND" presumes a database MIND does not
have, so this ADR also implies **giving MIND one** -- a new capability, not a
change to an existing one.

The plausible purpose is NOOA memory (`nooa-memory` is a package in the pinned
vendored tree), which would fit ADR 0048's NOOA push/pull mapping. But that is
inference, and it should be stated before it is built.

### 5. It makes gap 1 reachable at runtime

`back` and `backjob` share `mind-data` today. That is a defect, but a **static**
one: it takes a compose edit to create. Once `DB_PATH` is settable, two writers
on one file becomes a **runtime state** anyone holding the effect can produce.

The closed set must encode single-writer -- no two roles may be pointed at one
path -- and a checker must prove it. Otherwise this ADR converts a deployment
mistake into an available operation.

## Relation to `persist` (gap 16)

This is plausibly an **alternative** to a `persist` container rather than a
complement to one. Gap 16 stalls on SQLite having no server, so "persist owns
physical storage" is hard. Governing the *binding* between a container and its
store reaches much of the same goal -- who writes where becomes an admitted,
recorded decision -- without a storage-engine migration.

Whether `ROLE=persist` survives this ADR is **open**.

## Not decided here

Who may call the effect. Following ADR 0046's pattern, it should be a named
caller with an explicit operation, not any holder of a seam.

---

# Correction to section 4: NOOA embeds SQLite

Section 4 said MIND "has no database" and that this ADR implies **giving** it
one. That was measured only against our own Python. Corrected from the pinned
vendored tree:

**NOOA embeds SQLite.** `nooa/storage/sqlite.py` provides `SQLiteStorageManager`,
`_ensure_schema`, `delete_sqlite_database`, an explicit session lock
(`_acquire_session_lock`, `SessionAlreadyActiveError`), and virtiofs detection
for Docker Desktop file sharing.

The accurate statement is narrower and better founded:

> **MIND has a SQLite capability it does not bind.** This ADR does not give MIND
> a database; it binds one that currently defaults to memory.

## What is true today

| Fact | Consequence |
|---|---|
| `SQLiteStorageManager(db_path = ":memory:")` is the **default** | NOOA state does not reach disk unless a path is passed |
| Our MIND code never imports `nooa.storage` and never passes `db_path` | MIND takes that default |
| The `mind` compose service has **no `volumes:` key** | even a file-backed store would be **ephemeral** -- lost on every container recreate, and invisible, because nothing looks for it |

## Three things this changes

### 1. NOOA already solves single-writer -- borrow it, do not reinvent

Gap 43 worries that a settable `DB_PATH` makes two-writers-on-one-file a runtime
operation. NOOA enforces exactly that constraint for its own store, with a lock
file and a named error. The closed path set should adopt that mechanism rather
than grow a parallel one.

### 2. A path denotes three files, and the mount type matters

SQLite in WAL mode carries `-wal` and `-shm` sidecars; `delete_sqlite_database`
unlinks all three. An entry in the closed set (gap 39) therefore denotes a
**file triple**, not a filename.

And NOOA ships `_is_virtiofs` precisely because SQLite misbehaves on Docker
Desktop file sharing. ADR 0046 requires a **bind mount** for `down -v` survival.
Binding NOOA's store to a bind mount walks into the hazard the upstream is
checking for -- so the mount type is a decision, not a detail.

### 3. MIND's own system prompt becomes false

`mind_agent.py` tells the agent, in its instructions:

> You never persist anything; you only return a proposal for BACK to validate
> and commit. ... There is no second socket, and there is no write path for you
> at all.

ADR 0048 already made the "second socket" clause false. Giving MIND a durable
NOOA store makes the "never persist" clause false too.

This one is different in kind from stale documentation. It is **inside the
agent's system prompt** -- it is what the model is told about itself. A MIND
that carries memory across sessions while being instructed that it persists
nothing is an inconsistency in the cognition layer, not in the docs. Rewrite the
prompt in the same change that binds the store, or do not bind it.
