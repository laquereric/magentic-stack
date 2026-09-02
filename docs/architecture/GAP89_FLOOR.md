# Gap 89 — does the RefusalLog floor survive the faults we can test?

Measured 2026-08-31 from `356b762`. Floor: `RefusalLog` JSONL + heartbeat
as landed at `fb41771`. LOG does not exist; LOG-specific conditions
dropped. **No fix in this branch.** A failing result is the finding.

Plant: `tooling/cpcp/plant_refusal_floor.rb`. Scratch dir under `/tmp`,
RAM disk via `hdiutil`, a child process we spawned. Did not chmod the
repo, did not fill the host disk, did not SIGKILL anything we did not
start.

Two invariants per condition:

1. a refusal recorded **before** the fault is still there afterwards
2. the heartbeat still distinguishes **observer never ran** from **zero
   refusals**

Plus: a truncated or half-written JSONL line that still parses would be
worse than a missing one. Called out if seen. None seen.

## Results

| Condition | prior survives | heartbeat distinguishes | truncated/corrupt | Notes |
|---|---|---|---|---|
| restart (new interpreter, same files) | **yes** | **yes** | no | The floor is the files. A process restart is not a threat. |
| permission denied (`chmod 000` on a scratch dir) | **yes** | **yes** | no | `record` returns `false`, never raises. Prior line intact. |
| path missing — never created | n/a (first write) | **yes** | no | `mkdir_p` creates the dir. First record lands. |
| path missing — directory gone | **NO** | **NO** | n/a | Host loss of the files. See below. |
| SIGKILL mid-write | **yes** (marker) | **yes** | **no** | Could not catch `puts` mid-syscall. See below. |
| disk full (8 MiB APFS RAM disk) | **yes** | **yes** | no | Volume was **not at zero**. See below. |
| disk full (docker tmpfs) | skip | skip | skip | `ruby:3.4-alpine` not present; did not pull. |
| disk full (FAT32 RAM disk) | skip | skip | skip | `diskutil erasevolume FAT32` failed. |

## The FAILs (the finding)

### Directory gone is host loss, and recreate lies

After `rm -rf` of the log directory:

- the JSONL is gone
- the heartbeat is gone

`record` then `mkdir_p`s a fresh pair. Heartbeat says `ran:true` with
only the new refusal. A reader cannot tell "observer never ran", "zero
refusals", and "had refusals, then the directory vanished" apart.

**The floor is the file. There is no replica.** Manus marked host loss
as not established; it is now established as **not survived**.

This is not a surprise and not a bug to patch in this branch. It is
the bound: anything that unlinks the directory (container recreate
without a volume, `rm`, host disk wipe) wipes the evidence and the
next boot looks healthy.

### SIGKILL did not produce a torn line

Child writes a marker, then one 2 MiB `because`, then we SIGKILL.
On this machine the child finished both `record` calls before the
parent observed size growth (`killed_mid=false`, 2 parsed lines, 0
unparsed, 2_097_363 bytes). Typical refusal lines are tens of bytes.

What this does **not** prove: that `File#puts` is atomic, or that a
SIGKILL between `File.write` truncate of the heartbeat and the
new contents cannot leave an empty heartbeat (`ran?` is `File.file?`,
so an empty heartbeat file would look like the observer ran). We did
not catch that window.

What it does prove: under this plant, SIGKILL around a 2 MiB append
did not leave a half-parsed JSONL line. Absence of a torn line here
is not evidence that torn lines cannot happen.

### Disk full was not actually full

8 MiB APFS RAM disk. Filling a sibling file raised `ENOSPC`, then
`df` still showed **1008 KiB available**. The 112-byte JSONL append
succeeded (`during=true`). No truncated line.

APFS left a reserve. A FAT32 retry failed to format. Docker tmpfs
skipped (no image, no pull).

So: **we did not test zero-byte disk.** We tested "ENOSPC on a
neighbor file with ~1 MiB left", and the floor wrote fine. Claiming
"survives disk full" would be the plausible-but-wrong shape. The
limit is written here; the plant records `volume_at_zero=false`.

## What the floor actually guarantees, today

| Survives | Does not |
|---|---|
| producer process restart | deletion of the log directory |
| `chmod` of the directory at write time (prior records; new write refused, never raises) | host loss of the files |
| first write to a missing path (`mkdir_p`) | a proven zero-byte disk (not achieved) |
| SIGKILL after a completed `puts` (no torn line observed) | a proven mid-`puts` tear (not caught) |

Heartbeat distinction holds for restart, permission, first-write, and
the SIGKILL we landed. It **does not** hold across directory deletion
followed by recreate: recreate looks like a healthy observer with a
short log.

No `fsync` after append (source: `append_unlocked` is `flock` +
`puts`, `write_heartbeat_unlocked` is `File.write`). That is the
unbuffered assumption Manus flagged. Not changed here.

Follow-up (self-detection, fsync vs the five outcomes, CI is not
the production observer): [`GAP89_SELF.md`](GAP89_SELF.md).

## What this does not do

- Does not fix the floor.
- Does not add `fsync`.
- Does not build LOG.
- Does not fill the host disk (scratch + 8 MiB RAM disk only).
- Does not chmod the repo.
- Does not SIGKILL a process we did not start.
