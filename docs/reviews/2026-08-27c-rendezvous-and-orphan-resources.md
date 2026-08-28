# Review: what the parallel coding agents copied, and a 5G orphan nobody starts

**Date:** 2026-08-27
**Scope:** `~/.mm` occupancy, and the working tree it led to -- open item 4 of
[`2026-08-27b-substrate-silent-failure-review.md`](2026-08-27b-substrate-silent-failure-review.md),
which closed with *"`~/.mm` is 16G: `rendezvous` 5.1G and `models` 5.0G are
**unexamined**"*. This review examines them.

Both turned out to be real defects, and neither is the defect the size suggested.
`rendezvous` was not hoarding data -- it was **re-copying data it already had**.
`models` is not stale -- it is **live, and unowned**.

---

## Why this review exists

A directory being large is not a finding. It becomes one when you can say *what
put the bytes there* and *whether anything would notice if they left*. Review b
recorded the sizes and honestly declined to interpret them. That is the gap this
closes.

---

## 1 -- HIGH -- every slot rendezvous copied the entire SUPER object store

### What a rendezvous is

A per-slot bare git repo at `~/.mm/rendezvous/<slot>.git`. SUPER seeds it with a
base branch; the slot dials out, pushes its revised engine branch back, and SUPER
fetches from it. It is an **exchange point between two repos on the same disk**,
not an archive.

It was behaving like an archive. Seeding one meant `git push`-ing a full history
into an empty store, which copies every reachable object -- a second complete
copy of the substrate, per slot.

### Measured

| | |
|---|---|
| plain bare repo, seeded from substrate `main` | **532M** |
| identical seed, with `objects/info/alternates` | **88K** |
| six fixtures from one `scheduler_recycle_stale_turns_spec.rb` run | **2.7G** -> **528K** |

The spec spawns six panes. Every local run of it cost multiple gigabytes of
writes, on a volume at 96%.

### The fix

`objects/info/alternates` pointing at `<substrate>/.git/objects` -- exactly what
`git clone --shared` does. The seed then finds base objects already reachable and
copies almost nothing. Objects the **slot** pushes in still land in the
rendezvous' own store, so slot work survives independently of the alternate.

`gems/mmg-hypersource/.../execute.rb`, called after `git init --bare` at both
creation sites. Landed `edf9cca` (incomplete, see below) and `f94862c`;
`server/Gemfile` repinned and `bundle install` run.

### Verified, not assumed

Cheap is easy; cheap-and-still-working is the claim that matters.

- all six regenerated fixtures: **88K**, `objects/info/alternates` present
- `8 examples, 0 failures`
- `rst-live.git` resolves `refs/heads/arc/brf_brf_rst_0728ff70` -> `a57e919f6`
  and reads a **46-entry tree** -- small without being hollow

### The reviewer's failure, again, and what caught it

I wrote `link_alternates!` and reported it "wired into `ensure_rendezvous!` and
active in the bundled gem." It was not. The call had landed in
`ensure_gem_rendezvous!` -- the *cheap* per-gem repo -- while
`ensure_rendezvous!`, the slot repo that actually receives the 530M seed, never
called it. My verification had confirmed the string `link_alternates` appeared
twice in the active checkout. Both occurrences were the definition and the wrong
call site.

This is the same defect as the `head -6` and `--limit 300` errors in reviews a
and b: **I checked the shape of the evidence instead of the claim.** "Appears
twice" is not "is called from the method that matters."

What caught it was refusing to accept a contradiction. An isolated probe showed
the correct file, `link_alternates!` defined, `repo_root` correct, and
`created: true` -- and still no alternates file. That combination fits exactly one
explanation, and reading the method confirmed it in ten seconds. The lesson from
review b generalizes: *a check that has never failed has not been tested* -- and
a fix whose effect has never been **observed** has not been verified.

---

## 1b -- HIGH -- the rendezvous was the small instance of the pattern

The rendezvous duplication has a cause worth naming: **a slot-based parallel
coding agent clones source directories and builds them in place.** The
rendezvous copied an object store; the slot harness copies whole trees. Same
reflex, two orders of magnitude apart.

Measured across the substrate working tree -- **29G**, against 17Gi free:

| | | |
|---|---|---|
| `gems/` | **18G** | 285 entries, **283 nested git repos** |
| `server/` | 5.7G | |
| `.mm_tmp/` | 3.1G | |
| `.git/` | 636M | |
| `panes/` | 186M | |

Inside `gems/`, source is not what costs. Build output is:

| | source | build output |
|---|---|---|
| `mmg-grokbuild/upstream/grok-build` | `crates/` 61M, `.git` 14M | **`target/` 11G** |
| `mm-shacl-reader` | `src/` **44K** | `target/` **2.0G** |
| `mm-sal-tui` | `src/` **88K** | `target/` **680M** |
| `todo-app-rust` | `src/` **104K** | `target/` **603M** |
| `herb` | -- | `node_modules/` 634M + `vendor/` 535M |
| `mm-local-ai-boundary` | -- | `modelpack/` 469M |

**~15G of regenerable Rust and Node build cache, inside the working tree of a
repo on a volume at 96%.** `mm-shacl-reader` carries a 2.0G `target/` for 44K of
source -- a ratio of roughly 47,000:1.

### One copy, built twice -- checked, not assumed

The obvious worry is that a parallel agent left several clones of the same
upstream lying around. It did not. A full walk of the home directory --
**290,581 directories**, `Library` and `Trash` excluded -- finds **exactly one**
`grok-build` tree, confirmed twice over: once by directory name, once by
`.git/config` remote (`laquereric/grok-build`). `mmg-opencode/upstream` (165M)
is the only other vendored upstream, and it is a different project.

So the waste is not duplicated *source*. It is unshared *output*:

- that single clone holds **`release/` 7.6G + `debug/` 3.4G** -- two complete
  builds of the same 61M of code, both kept
- **no `CARGO_TARGET_DIR` is configured** anywhere, so each of the four Rust
  projects compiles its dependencies into its own tree: 12.1G + 2.2G + 0.7G +
  0.6G = **15.6G**, with substantial overlap between them
- the shared caches that *should* absorb this are comparatively tiny:
  `~/.cargo` 115M, `~/.rustup` 3.0G

That is a better finding than "it made copies of the source," and it points at a
different fix -- one `CARGO_TARGET_DIR`, and not retaining both profiles.

*Method note: `find` is blocked for this process under the home directory and
returns zero for everything, so this used an explicit `os.walk`. An earlier glob
search returned "no other copies" while being too shallow to have found even the
known one; it was rerun with a positive control asserting the known copy appears.
Spotlight (`mdfind`) also returned nothing for a tree that demonstrably exists.*

### Why nobody saw it

`.gitignore:72` is `/gems/`, and the gems are 283 *nested* repos, each ignoring
its own `target/` and `node_modules/`. So:

- `git status` in the substrate: **0 dirty under `gems/`**
- `git ls-files target` / `node_modules` in each gem: **0 tracked**

Every signal a developer normally reads says clean. The 18G is invisible to git
by construction -- correctly ignored, and therefore never counted. It shows up
only in `du`, which nothing runs.

This is the same shape as the WAL stall in review b and the rendezvous above: a
system doing exactly what it was told, with nothing measuring the cost.

### What follows from it

None of it is tracked, so **none of it is at risk** -- `cargo clean` and removing
`node_modules` reclaim ~15G with no loss beyond rebuild time. That is a
judgement call about rebuild cost, not a correctness question, so it is left to
the operator rather than done here.

The structural fix is the same one the rendezvous just got: **a build agent
should not materialize a private copy of something that already exists on the
disk.** For git objects that is `objects/info/alternates`. For cargo it is a
shared `CARGO_TARGET_DIR`; for node, a shared store. Today each slot-cloned gem
builds into its own tree and keeps the result forever, because nothing ever told
it not to.

---

## 2 -- MEDIUM -- 52 commits exist only inside a rendezvous

Across the four `local-*` rendezvous, **279 refs**; **52** name objects that do
not exist in the SUPER repo at all.

| rendezvous | refs | absent from SUPER |
|---|---|---|
| `local-slot-1.git` | 153 | **34** |
| `local-slot-2.git` | 111 | **15** |
| `local-worker-1.git` | 14 | **3** |
| `local-conv-grok-claude.git` | 1 | 0 |

These are engine attempts a slot pushed back that SUPER never fetched. They are
not backed up, not on origin, and live in a directory whose name says "scratch."
Whether they are worth keeping is a judgement I cannot make -- but *deleting them
without looking* is not available, and that is the point of recording it.

This is why the four fat `local-*` repos (2.4G) were **left alone** today.
Shrinking them is safe in principle -- add the alternate, repack locally -- but it
edits live slot state, and 52 unique commits is the wrong thing to be casual
about.

---

## 3 -- MEDIUM -- 5.0G serving a model no committed code calls

`~/.mm/models` is a single file: `granite-4.1-8b-Q4_K_M.gguf`, 5.0G, downloaded
Jul 15.

The instinct is "stale download, delete it." That instinct is wrong:

```
llama-server -m ~/.mm/models/llama/granite-4.1-8b-Q4_K_M.gguf \
  --host 127.0.0.1 --port 8080 -c 8192 -ngl 99 --jinja --alias granite-4.1-8b
```

PID 11591, running since Monday, holding the file open, and **answering**:
`/v1/models` returns `granite-4.1-8b`. It is live.

And nothing owns it:

- **PPID 1** -- started by hand in a shell that has since exited
- **no launchd plist** references it (`~/Library/LaunchAgents`, `~/.mm/launchd`)
- **no code references it**: `granite`, `mm/models`, `127.0.0.1:8080` and
  `localhost:8080` return zero hits across `bin/`, `gems/`, `server/config`,
  `server/packs`, and a repo-wide search of the substrate

So: a resident 5G inference server, unsupervised, unrestarted on reboot, that no
committed code calls and no committed code starts. Either it is load-bearing for
something outside this repo -- in which case it belongs under mm-tic like every
other floor service -- or it is a July experiment still holding 5G and a process
slot. **I cannot tell which from inside the repo, and the operator can.** That
ambiguity is itself the finding: nothing on disk records the answer.

*Scope limit: I searched the substrate repo only, not magentic-stack or the other
repos on disk.*

---

## 4 -- the assumption the fix depends on, stated plainly

The alternate makes the rendezvous depend on the SUPER object store. The in-code
comment asserts *"safe against gc: base objects stay reachable from SUPER refs."*

That is true **only while SUPER keeps those refs.** If a base branch is deleted
and SUPER is gc'd, objects a rendezvous reads through the alternate can be pruned
under it. Today that risk is near zero -- the fixtures point at `main` -- but it
is not structurally zero, and **3,077 merged branches were deleted from this repo
earlier today.** The two facts belong in the same sentence.

This is reasoning, not a measurement: I did not construct the failure. Recording
it unproven is deliberate -- an unstated assumption is how the WAL stall in review
b went two days unnoticed.

The durable answer is `git gc --keep-unreachable` on SUPER, or seeding rendezvous
only from refs SUPER is committed to retaining. Neither is done.

---

## 5 -- State

`~/.mm`, largest first:

| | | |
|---|---|---|
| `models` | 5.0G | live, unowned -- finding 3 |
| `oxigraph-data` | 3.8G | was 3.6G in review b, after a rebuild to 482M |
| `rendezvous` | 2.4G | all of it the four `local-*`; fixtures now 528K |
| `logs` | 606M | |

And the repo tree itself, which review b never measured:

| | | |
|---|---|---|
| substrate working tree | **29G** | `gems/` 18G, of which ~15G is regenerable build cache -- finding 1b |

Data volume: **96% used, 17Gi free** (18Gi in review b).

The store trend from review b's open item 1 continues in the same direction.
Still inside the "needs a week of observation" window it was given, but it has not
turned around.

---

## 6 -- Recommendation

Review b's finding was *components reporting success while checking nothing*.
This one is narrower and more mundane:

**Nothing in this system records who owns a resource.** A 5G model with a live
server and no plist; 52 commits in a scratch directory; a rendezvous that copied a
full object store because nobody had written down that it is an exchange point,
not an archive. Each is cheap to fix once seen and invisible until measured.

The cheap countermeasure is the one already proven twice today: **make the
expectation executable.** `check_closed.py` and `check-bin-paths` exist because
unenforced structure drifts back. A supervised-services assertion -- every
long-running process on this box is either named by a launchd plist or explained
in a ledger -- would have caught finding 3 in July, not today.

---

## Method

Sizes from `du -sh` over full listings, not `head`. Ref counts from
`git show-ref | cut -d' ' -f1` with `git cat-file -e` against SUPER, per ref, no
sampling -- an earlier version of that check used a mangled `%%(objectname)`
format and returned a uniform, plausible, wrong answer. Process ownership from
`ps`, `lsof`, and PPID rather than `pgrep -f`, which matches the querying command
itself. The fix was verified by observing its effect on regenerated fixtures, not
by reading the source -- reading the source is what produced the error in
finding 1.

Occupancy from `du -sh` over full globs, run detached and polled without
`sleep` inside the call. Two tooling notes worth recording, because both
returned a confident wrong answer: `find` under the home directory returns
**zero** results for this process (macOS TCC), which reads identically to "no
matches" -- globs and `ls` work and were used instead. And `git check-ignore -v
gems` reported *not ignored* when `.gitignore:72` plainly contains `/gems/`;
the rule is real and the invocation was wrong. Both are the review-b failure
mode in miniature: a tool that answers, rather than refuses, when it cannot
see.
