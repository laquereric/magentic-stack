# Review 2026-08-25 — external surface and internal organization

Evidence gathered live, not from memory. Every number here was measured on the
day; where something is inferred rather than observed it says so.

---

# 1. External

## 1.1 Deployed sites — healthy

```
stewardshiptranslation.com/board.html   200   0.32s
stewardshiptranslation.com/up           200   0.06s
magenticmarket.ai/                      200   0.30s
```

Seven containers on 31.97.8.47, all up:

| container | role |
|---|---|
| `mm-edge` | Caddy, the only thing on :80/:443 |
| `stewardshiptranslation` | the site (BACK) |
| `stewardshiptranslation-backjob` | same image, `ROLE=backjob`, reconciles the graph |
| `mm-graph` | oxigraph, pod-internal only, volume-backed |
| `mm-switch` | LLM plane; keystore on a volume, UI on loopback |
| `mm-mind` | NOOA cognition; no credential, two reachable hosts |
| `magenticmarket-ai` | the second site |

The whole pod deploys from one script in the repo (`bin/deploy.rb`) and survives
a full redeploy, verified twice.

## 1.2 Two outages today, both silent

Neither announced itself. Both were found while looking for something else.

**mm-edge restart loop.** The VPS rebooted at 14:48; host `nginx` (enabled at
boot, serving only the stock default page) took `:80` before Caddy could. Caddy
could not bind and looped. `docker ps` showed six healthy and one `Restarting`,
which reads as noise. **Both sites were down for ~34 minutes** and nothing said
so. Fixed by stopping AND disabling nginx — the stop alone would have recurred
on the next boot.

**Time Machine had been failing for days.** The destination `VENTOY` was not
attached, so every backup failed to mount and macOS fell back to local
snapshots — which are only thinned after a SUCCESSFUL backup. Three had
accumulated, pinning ~100 GB. This presented as a full disk, and a day of
deletions returned almost nothing.

**The pattern is the finding.** A background job that retries silently does not
look like a failure; it looks like unrelated symptoms elsewhere. Both were
diagnosed only by asking why an unrelated number was wrong.

## 1.3 GitHub — 936 repos, 10 public

```
total            936
public            10   (1%)
private          926
no description   517   (55%)
```

The public face:

| repo | state |
|---|---|
| `magentic-stack` | the monorepo, current |
| `coordination-protocol-contract-package` | the CPCP standard + registry, renamed today |
| `osi-level-8`, `osi-level-8-profiles`, `json-rpc-ld` | the protocol family |
| `magentic-runtime` | runtime |
| `Publications`, `DataYoursSoftwareMine`, `.github`, `laquereric` | supporting |

Ten coherent repos. The problem is not the public face; it is the 926 behind it,
over half with no description at all. A private repo with no description is
indistinguishable from an abandoned one six months later, and there are 517.

## 1.4 CPCP naming — resolved today, and it had drifted three ways

The acronym carried **three** live expansions simultaneously:

| expansion | where |
|---|---|
| Cyborg Pod Contract Package | the standard repo name, README, and `rdfs:comment` in `cpcp-base.ttl` |
| PubSubStandard_1 / JSON-RPC-LD-PS1 | the `rails-cpcp` gemspec and README |
| **coordination-protocol-contract-package** | settled |

All three are now reconciled: the standard repo renamed, its README and ontology
rewritten, the gem's README and gemspec rewritten, and a note left where the
third expansion had been recorded.

**The letters did not move**, which is why this cost nothing: the vocabulary IRI
`https://w3id.org/laquereric/cpcp/ns#`, the `/_cpcp` mount, the
`JSON-RPC-LD-PS1` identifier and every `PS1-P{N}` id are untouched across 175
files and two live sites.

---

# 2. Internal

## 2.1 The dominant defect: one gem, two homes

Seven gems exist in **both** `magentic-stack/interfaces/` and
`magentic-market-ai/gems/`:

```
interfaces/  12 entries        gems/  295 entries

in both (7), with drift:
  rails-cpcp              0 differing files   (synced today)
  mmg-semantic-editor     2
  vv-html-components      2
  mmg-blob                3
  vv-blob                 3
  vv-graph                4
  rails-osi-level-8      27   <-- see below
```

This is not a tidiness problem. It cost real time today, three times:

- The CPCP rewrite and `SqliteIdempotency` went into the copy **without a
  remote**. The published repo did not have them until they were ported across.
- The MIND board-cycle rewrite went into a copy of `mind-pod` in the CONSUMER
  repo, not the tracked baseline.
- `mmg-acia` and `mmg-acia-crud` were declared non-existent in a landed ADR
  because only `interfaces/` was searched. Both exist, with their own repos and
  history.

Each time the same error: **concluding from one directory.**

## 2.2 rails-osi-level-8: production runs code its own repo has never seen

The worst instance, and worth stating on its own.

```
laquereric/rails-osi-level-8   1 commit, dated 2026-08-18, the scaffold
                               profile9/: 0 files      spec/: 0 files

magentic-stack copy            profile9/: 14 files     spec/: 8 files
                               + intent/, authorization, cid, fixtures,
                                 known_refusal, db/, data/
```

The base image builds this gem from the **magentic-stack clone**, so the stack
copy is what runs both live sites. The published repo contains a scaffold and
nothing else. Anyone who cloned `rails-osi-level-8` would get something that
cannot render a board.

This is the same shape as `rails-cpcp` before today, but larger and unnoticed.

## 2.3 What worked, and is worth keeping

**Never-raise envelopes and typed refusals.** Repeatedly turned what would have
been a silent wrong answer into a legible one: `unknown_compose_noun`,
`compose_not_supported`, `remove_required`, `mind_not_configured`,
`volume_not_mounted`. The refusals name the offending item, so the fix does not
require guessing.

**Closed shapes.** The Profile 9 shape gate refused two invented document
predicates and caught a whole record assigned where a node id belonged. Neither
would have failed loudly otherwise.

**Content addressing.** A digest cannot come to mean different bytes. It made
dedup free, made "the board returned to a state we already hold" answerable, and
made a wrong node-id scheme detectable by comparing rendered `data-ux-node-cid`
against projected triples.

**Declarations that refuse unknown keys.** `mmg-vpc`'s declaration validator
rejected `env` the first time it was passed. That is a closed contract behaving
correctly, and it took thirty seconds to widen deliberately.

## 2.4 Process failures observed today

**Specs assert documents, not what renders.** Every existing spec passed while
five undeclared `<textarea>` elements were live on a page, and again while the
removal dialog rendered `display:none`. A control that exists in the markup and
cannot be seen passes everything. The new `compose_spec` and `projection_spec`
COUNT rendered output and compare against the DOM; that is the pattern to spread.

**Deleting before verifying.** Twice I proposed deleting something on the basis
of a partial comparison — `runtimes/` (compared only `mind/`, concluded
"redundant"; it was a pre-vv-base fork) and the six models (established nothing
referenced them, but had not checked the migration was faithful). Both turned
out safe only after the check that should have come first.

**Concluding from one directory.** Stated three times above. It is the single
most expensive habit visible in this session.

**A rename executed on an established-false premise.** `rename public repo CPCP`
named a public repo; the repo found was private; that was reported — and it was
renamed anyway, taking the name the actual target needed. Being right about the
evidence and then acting against it is worse than not checking.

## 2.5 Repo organization — recommendations

1. **Pick one home per gem.** The `interfaces/` vs `gems/` split has no rule
   anyone can state, and the deployed artifact is decided by which one the base
   image happens to build. Until it is resolved, every edit is a coin flip about
   whether it reaches production or the published repo.
2. **Push `rails-osi-level-8`.** Its repo is a scaffold while its code runs two
   sites.
3. **Describe or archive.** 517 repos with no description is not an inventory,
   it is a heap. A one-line description is cheap; archiving is cheaper than
   remembering.
4. **Ship only the build context.** `runtimes/` was excluded from shipping today
   (83 MB -> 18 MB per deploy, 83s -> 26s). The general rule — a source root is
   not a build context — applies to the next stray directory too.

## 2.6 Open, and owned by the operator

- **~100 GB** pinned by Time Machine local snapshots. Releasing on its own now
  that VENTOY is attached; `tmutil deletelocalsnapshots` is immediate and
  irreversible.
- **`health-rdf.log` has no rotation.** Trimmed from 87 GB today; the writer is
  unchanged, so it grows back.
- **`rails-cpcp` is private** while several documents called it public. Documents
  corrected; visibility deliberately not changed.
- **ADR 0003 decision 1** — moving ACIA into `mmg-acia` — is unresolved and now
  known to be a convergence of two vocabularies, not an extraction.
