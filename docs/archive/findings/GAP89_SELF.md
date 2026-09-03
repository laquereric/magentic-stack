# Gap 89 follow-up: can the floor detect its own loss from inside?

Asked 2026-09-02 against `d5d106d`. Floor source: `RefusalLog`
(`append_unlocked` is `flock` + `puts`; `write_heartbeat_unlocked` is
`File.write`; neither `fsync`s). Gap 89 measured the faults.
**This is the answer, not a fix.** Did not patch the floor. Did not
add `fsync`. Did not build LOG.

## 1. Impossible in principle, not merely absent

Two histories, one filesystem:

| | H1 | H2 |
|---|---|---|
| past | observer never ran | N refusals were on disk |
| fault | — | `rm -rf` of the log directory |
| next `record` | `mkdir_p`, heartbeat `ran:true`, one JSONL line | identical |

Any function of the **current files** returns the same value on H1 and
H2. Therefore no in-container reader of the floor can tell "never ran"
from "had refusals, then the directory vanished" from "zero refusals
then first write". That is the distinguishability rule ADR 0054
borrowed from 0052, and the files are the only input.

This is not an implementation gap. The floor **is** the files. After
the files are gone, the evidence is gone. Recreate is a healthy short
log because `mkdir_p` is the first-write path, which gap 89 showed
works. A replica, a generation number, or an in-memory count would be
a **second** store. If that second store shares the lost directory, it
dies with the first. If it lives only in the producer process, it dies
on restart — and the operational case (container recreate, host wipe)
kills the process too.

Unlink-while-the-producer-is-still-alive is a narrower window: RAM
could disagree with disk. This floor does not keep RAM of `N`. Even if
it did, that window is not the threat gap 89 named. The threat is host
loss of the files, after which the successor process has no RAM and no
files.

**Reasoned NO.** In-container self-detection of floor loss, after the
floor is gone, is impossible. Adding another file next to it is not
self-detection; it is a replica in the same failure domain.

## 2. The minimum outside observer; CI is not it

ADR 0054 already has this: the last link is RETAIN and WATCH in a
failure domain that is not the refuser, and "that last link is not
established to exist here." Directory-gone is an instance, not a new
requirement.

Minimum that closes the distinguishability hole:

1. **WATCH** — something expects a heartbeat from this container
   *instance* on an interval, and treats silence as a signal (not as
   zero refusals).
2. **RETAIN** — the last-seen heartbeat / seq / digest lives **outside
   the container filesystem** (the thing gap 89 unlinked).

That is a supervisor, a node agent, or an operator. It is not RES
(retains, does not watch; correlated Rails image). It is not LOG (row
87: helps when the shared lineage is healthy; cannot evidence that the
lineage failed). Do not build LOG to close this.

**CI observes the mechanism, not production incidents.**
`check_refusal_observer.py` proves the collector is hooked.
`plant_refusal_floor.rb` proved directory-gone is not survived. A CI
artifact is an observation of a test run. It does not watch a running
BACK, and it does not retain production refusals. Treating CI as the
final observation point would assert a property it does not have —
the failure 0054 exists to stop.

## 3. fsync changes none of the five gap-89 outcomes

Source, not a re-run. `append_unlocked`:

```ruby
File.open(path, "a") { |f| f.flock(File::LOCK_EX); f.puts(JSON.generate(event)) }
```

`write_heartbeat_unlocked`: `File.write` (truncate, write, close).
No `fsync`, no `fdatasync`, no `O_SYNC`.

| Condition | gap 89 | would fsync change it? |
|---|---|---|
| restart (new interpreter, same files) | both invariants hold | **no** — the bytes are already visible to the next process; fsync is about surviving a *machine* crash, not a process restart |
| chmod 000 on the dir | prior survives; new `record` returns false | **no** — the prior append already completed; the new write is an EACCES, not a durability miss |
| first write (path never created) | `mkdir_p`, lands | **no** — the test is "the first record exists", which `puts` already did |
| directory gone | both invariants **fail** | **no** — fsync does not resurrect unlinked files |
| SIGKILL around a 2 MiB append | no torn line observed; `killed_mid=false` | **no for that plant.** `write(2)` had returned; kernel dirty pages survive process SIGKILL. fsync would not have made `puts` atomic, so it would not have prevented a tear *during* `write(2)` either. The plant did not catch that window, with or without fsync |

Disk full (the extra row): the volume was not at zero. fsync of a
successful 112-byte append does not change "ENOSPC on a neighbor with
~1 MiB left." Still not a zero-byte disk test.

What fsync **would** change is a sixth, untested condition: **host
crash / power loss after `write(2)` returns and before the pages hit
the device.** That is not one of the five. Claiming fsync as the
directory-gone fix, or as the SIGKILL-tear fix, would be
plausible-but-wrong.

Heartbeat `File.write` still has a truncate-then-write window. An
empty heartbeat file is `File.file?` => `ran?` true. fsync after a
completed write does not close that window; write-to-temp-and-rename
would, and is also a patch, so not done here.

## What this does not do

- Does not fix the floor.
- Does not add `fsync`.
- Does not add an in-memory generation.
- Does not build LOG.
- Does not name a supervisor. 0054 already said the last link is not
  established; this note does not invent one.
