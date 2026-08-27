# Review: three silent failures and the class of defect behind them

**Date:** 2026-08-27
**Scope:** the graph store, mm-tic's boot gate, and the debris of `3625ec37c`
**Reviewer:** SuperDevAi
**Verdict:** all three fixed and asserted. The common cause is not a bug, it is a
habit: **things that report success without checking anything.**

---

## 1. The graph store had stopped accepting writes two days earlier

`~/.mm/oxigraph-data` held **65G to store ~189K triples** -- 23G of SST and **42G
of write-ahead log**. RocksDB's own log said why, 181 times:

> `Background IO error: No space left on device`
> `Stopping writes because we have 43 immutable memtables (waiting for flush)`

On **2026-08-25 at 10:20** the disk filled. RocksDB could not flush memtables to
SST, so it stopped accepting writes -- and a WAL cannot be released until its
memtable flushes, so the log grew instead. Disk full, cannot flush, WAL grows,
more disk full.

**It answered `SELECT` with HTTP 200 in 1.7ms throughout.** `urn:mmg:sal:public`
-- the graph the ACIA work publishes to -- returned **zero**. The substrate ran
for two days on the premise that the graph was its truth while the graph was
recording nothing, and every health check agreed it was fine.

The tell, in hindsight: `LOG` had not been written since Aug 25 10:20 while the
newest `.log` file was two days newer. That gap is the signature.

### What was actually driving it

Not accumulation. `project_to_graph` PUTs to `/store?graph=`, which **replaces**
`urn:mm:otel#` -- so every cycle deletes and reinserts ~185K triples into the
WAL. Measured across a projection boundary:

```
18:20:57   5864M  wal=15
18:21:57   6071M  wal=16     <- one projection: +207M, one new WAL file
```

At the 300s cadence that is 2.5GB/hour, **59GB/day**, for a health surface whose
only question is "is it healthy now".

### Fixed

| | |
|---|---|
| `6b7294b89` | `--out` on the registry's health-rdf tick. It emitted N-Triples to **stdout**, which a tic tick captures to a log: 8.7G across 71.5M lines, 91% of `~/.mm/logs`, for a file nothing reads. **24,154,272 bytes per run became 107.** |
| `bd0cfa86b` | `MM_TIC_PROJECT_S` 300 -> 3600. ~59GB/day -> ~5GB/day. Safe because steady-state liveness does not read this graph and boot force-projects regardless. |
| `076179ddf` | **A write probe.** `graph_write_roundtrip?` PUTs a nonce and ASKs it back every 300s; on failure `ready_gate` falls back to deterministic probes. Proved against a server that returns 200 and never persists -- the exact Aug 25 shape. |

Two changes did **not** help and say so in their own commits: a retention tick
(`4f44202eb`) deletes by age from a graph that is wholly replaced, and a 60s
projection window (`f8c35386f`, corrected by `166d9bd94`) measured *larger* than
300s at settled load.

---

## 2. Boot spent three minutes lying, then one minute telling the truth

Every mm-tic restart took 3+ minutes because stages 5-8 each sat through the full
60s `BOOT_TIMEOUT`. Three separate defects, found in layers:

**The SPARQL gate was a veto.** `ready?` let the Silver gate overrule a
deterministic probe that had already proven a service up. The gate asks whether
`urn:mm:otel#` holds a recent healthy gauge -- but an *adopted* daemon that is
plainly serving may have emitted nothing inside the projection window. The ensure
loop already had this right and said so in its own comment; boot did not follow
it. `b8f0a1117` makes the deterministic probe ground truth and SPARQL the
fallback. **3+ minutes -> 73s.**

**`@graph_ready` latched.** Set once when the graph came up, never cleared. After
the graph went away, `ready_gate` still answered `"sparql"`, and the sparql path
force-projects -- so mm-tic logged `PROJECT_FAIL ECONNREFUSED` every ~3s and
**never reached the spawn that would have fixed it**. `boot_stage` calls
`ready?(project: true)` *before* `spawn_ensure`. Seen live: the graph only came
back because I started the supervisor by hand. `8a134f7ca` un-latches it and
skips projection unless the endpoint is listening.

**One stage was telling the truth all along.** `sparql-endpoints-supervisor` kept
failing honestly: `~/.mm/sparql.sock` existed but refused connections, because
its supervisor's breaker had tripped -- `RATE_LIMITED: exceeds 10 restarts/hr`.
It had been spawning `vv-sparql-endpoints-rust` every 30s since that binary was
deleted months earlier: 388K of `No such file or directory`. The registry comment
above the probe had anticipated exactly this -- *"a stale .sock file is still
`File.socket?` true but refuses connection, so connecting is the honest test"* --
and the probe was the only component not lying. `f8871bbff` retires the entry.

**Boot is now 7 stages in under a second, 0 NOT READY.**

---

## 3. A deleted directory nobody swept

`3625ec37c` ("complete vendor/ removal (gem-morph)") deleted `vendor/` and left
every reference to it in place. Four months later they were still surfacing one
incident at a time, each found *after* it broke something:

- the `.mcp.json` drift
- vv-graph path friction -- agents opening Turns on `vendor/vv-graph/**`
- the sparql-endpoints ghost above
- `bin/mm-mlx-agent` dying with a `LoadError` before it could report anything
- in **this** repo: `mind-pod` referencing `vendor/rails-osi-level-8` twice, and
  a CI step running `bash app/bin/prepare` -- a script deleted by `e215ea1`.
  Actions runs `bash -e`, so **Gate 1 Part C was aborting on that line.**

21 distinct `vendor/` paths in the substrate's `bin/`, every one missing.

The answer in each case was one of three, and naming them mattered more than
fixing them: **repoint** (it moved), **retire** (it is gone on purpose), or
**refuse** (keep the code, decline with an envelope). `bin/mm-hyper` already did
the third and became the model.

Asserted now in both repos: `bin/check-bin-paths` (substrate, hourly tic tick)
and `no-vendor-references` in `check_closed.py` (here, Gate 1). Both fail closed.

### The correct answer was already written down

`runtimes/mind-pod/app/Gemfile` has said this since the re-cut:

> rails-cpcp and rails-osi-level-8 come from the BASE image ... **No `path:`, no
> `git:`, no `bin/prepare` vendoring step**

The Gemfile was updated. The initializer, the spec helper and the workflow were
not. The fix was to make three files agree with a comment already in the same
directory.

---

## 4. The reviewer's own failure mode

This belongs in the review because it recurred five times in one day, and because
every instance produced a confident, wrong statement that someone could act on.

**I matched the shape of a thing and inferred its content.**

| I checked | I concluded | Actually |
|---|---|---|
| `head -6` of a branch list | "the password file is in 6 branches" | 8 -- I read my own truncation as the set |
| `gh repo list --limit 300` returned 300 | "300 repos" | 936 |
| `Mm::Chron` absent at its old path | "the scheduler never landed" | landed in **7 gems**, gem-owned by operator decision 4 days after that branch |
| `o:ts` exists on otel subjects | keyed retention on it | present on **2 of 2,333**; the real keys are `tsUnixNano` / `startUnixNano` |
| `DEEPSEEK_API_KEY=sk-` + 32 chars | "a real key, rotate it" | 32 copies of **one character** -- a placeholder in a scraped Medium tutorial |

The last one is the sharpest. I asserted it in a commit message, and the operator
acted on it by asking me to rotate a key that does not exist. One
`fold -w1 | sort -u` would have shown a single distinct character.

Two measurement errors of the same family:

- I reported a 3.5x win from a 60s projection window. That reading was taken
  during a burst; at settled load 300s/120s/60s all converge and 60s is slightly
  **larger**. Corrected in `166d9bd94`.
- Then I nearly withdrew the write-amplification concern entirely because a 20s
  and a 3-minute sample both showed **zero growth**. They were landing between
  300s projections. The quantity was per-event; **sampling faster than the event
  measures nothing and calls it stable.**

What worked, consistently: planting a violation and requiring the check to fail.
Every assertion shipped today was proved in both directions --
`check_closed.py`'s six, `check-bin-paths`'s three, the write probe against a
server that returns 200 and never persists. `check-bin-paths` then caught **me**
repointing five references from `vendor/X` to `gems/X` when those `gems/` paths
did not exist either. Moving a dangling reference to a nicer-looking directory is
not fixing it, and the ratchet said so within seconds.

---

## 5. State, and what is still open

| | |
|---|---|
| graph store | rebuilt twice; 6 named graphs; `sal:public` republished from AR |
| boot | 7 stages, <1s, 0 NOT READY |
| `check_closed.py` | **6 checks OK** |
| `check-bin-paths` | 144 scripts, **0 dangling, 0 ledger, 0 new** |
| local branches | 3,467 -> **1**; all 173 unmerged pushed to origin first |
| disk | 96% used, **19Gi free** |

**Open, and honestly stated:**

1. **The store is 3.6G again**, an hour after a rebuild to 482M. Hourly
   projection is not the whole story: `boot_stage` force-projects per stage, and
   I restarted mm-tic six times today. Restarts are a WAL driver. SST is now 16
   files to 11 WAL, so RocksDB *is* flushing -- healthier than the stalled state,
   but the trend deserves a week of observation before anyone calls it solved.
2. **A live Rails `master.key` sits beside its `credentials.yml.enc` in 121
   branches**, now durably on origin (private). Verified `^[0-9a-f]{32}$`, no
   placeholder markers. Rotating and stripping is outstanding.
3. **~40 `vendor/` mentions remain in the substrate's `bin/`** as comments and
   shell string-building the checker deliberately cannot see. Known limit,
   written into the friction note rather than papered over.
4. **`~/.mm` is 16G**: `rendezvous` 5.1G and `models` 5.0G are unexamined.

## 6. The one recommendation

Every failure here was a component reporting success while checking nothing: a
store answering reads it could not write, a gate trusting a stale gauge, a
supervisor spawning a deleted binary, a checker with an empty population. The
substrate's never-raise envelope makes this easy to do accidentally -- refusing
quietly and failing quietly look identical from outside.

**A check that has never failed has not been tested.** Plant a violation, watch
it fail, then trust it. That single discipline found or corrected every real
finding in this review, including the ones that were mine.
