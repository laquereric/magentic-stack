# Parallel agent work — what collided, and what caught it

**Measured 2026-09-11 → 2026-09-15** across magentic-stack,
shared-ai-space-app and switchyard-offline. A record first; the four
questions it raised were answered on 09-15 and two of them became gates
— see [§Decided](#decided-2026-09-15).

`tooling/slo/README.md` already states the premise:

> This repository *is* an agent fleet. grok, Manus and Claude ship
> changes to these gems continuously.

That is true, and this window is what it cost and what it bought.

---

## The window

Two streams interleaved on 2026-09-13, visible in the timestamps and
distinguishable only by commit-message style — `feat(scope):` on one
side, prose subjects on the other:

```
07:07  feat(pins): declare pydantic, monty, and genai-prices
09:57  Land the design documents the fleet has been writing against
09:58  Five gems: two extractions, three contracts, one of them blocked
10:00  feat(monty): gitlink the pin and wrap CodeAct
10:07  Wire the five gems into the loader, the base image, and the floor
10:29  feat(monty): install pydantic-monty in MIND
10:41  Two suites that were red before any of this landed
10:58  feat(pins): overlay genai-prices onto the ROLE=config catalog
…
14:39  Land grok/pydantic-upgrades          ← the two streams merge
```

Neither stream was wrong. They were working in the same tree at the
same time without seeing each other.

---

## What collided

| # | Collision | Caught by | Cost |
|---|---|---|---|
| 1 | **Two ADRs numbered 0070** — monty (authored 07:07) and never-persist (14:39) | `mmg-adr` ingest: *"body digest cannot change on a accepted ADR"* | one renumber, seven filename links checked |
| 2 | **Two ADRs numbered 0071** — the renumbered monty and front-is-bun, on a branch that *contained* the renumber | same gate | second renumber, six reference sites |
| 3 | `check_monty_pin.py` names its ADR **by path**; the rename would have broken it | it fails closed — went red rather than silently passing | caught during the same fix |
| 4 | `plant_mind_cells` could not plant after the NOOA merge — its target `COPY` line gained `mind_codeact.py` | *"could not plant"* rather than a pass | one literal updated |
| 5 | `vv-dependency-orch` **moved repos mid-session** (switchyard-offline → magentic-stack); a spec fixture then named `upstreams/` | `check_boundary` — reserved prefix | fixture renamed |
| 6 | `vv-sdlc` appeared untracked in `gems/` | `check_closed` — *absent from root Gemfile* | adopted, one commit |
| 7 | Two different `CANONICAL.md` — one untracked in main, one on the branch. Main's said the catalog ships **seven** task kinds; the branch shipped **twelve** | **nothing.** Found by hand during a blocked merge | settled by counting the kinds |
| 8 | `shared-ai-space-app` main gained U1–U7 while a branch existed; **13 of 19** dirty files were byte-identical to the branch | **nothing.** Found by hashing each file against the branch | one parked patch |
| 9 | `plan_mission_to_ui.md` and `plan_ledger_reporting.md` were both edited by another agent after being written | **nothing.** Noticed only because the harness reported the file changed | none this time |
| 10 | Planter residue (`# planted drift` in `pod-note.yaml`) from sweeps killed mid-`finally` | the next sweep, as four unrelated-looking failures | ~20 minutes of misdirected diagnosis |

---

## The finding

**The gate net catches structural collisions and is blind to semantic
ones.**

Everything in rows 1–6 is structural: an id claimed twice, a path that
moved, a registration missing, a reserved prefix. Those were caught
automatically, immediately, and by a gate that fails closed. Two of them
(3 and 4) were caught *because a check refused rather than passed* —
the failure mode this repo has spent the most effort designing for.

Rows 7–9 are semantic: two prose documents describing the same thing
differently, two implementations of the same stage, one agent editing
another's file. Nothing caught any of them. They were found by hand,
and row 7 was found only because an unrelated merge happened to be
blocked by the untracked file.

Row 7 is the one worth staring at. Both `CANONICAL.md` files were
plausible. The difference was a factual claim — *"ships seven"* versus
*"ships all twelve"* — and it was settled by **counting the task kinds
in `Ui::Catalog`**, not by preferring a copy. A gate could have caught
that one: a doc asserting a count that the code contradicts is
checkable. Nothing does.

---

## The attribution problem

**Every commit in this window has the same git author.** The agent is
inferable only from commit-message style and branch name
(`grok/pydantic-upgrades`, `canonical-gaps`). `git log --author` cannot
answer "which agent shipped this", and neither can `blame`.

That is survivable while the fleet is small and the styles differ. It
stops being survivable the moment two agents adopt the same style, or
when someone needs to ask *which* agent introduced a regression and in
what context.

Branch naming carried more signal than authorship did.

---

## What worked

Worth recording, because the failures are louder:

- **Fail-closed gates.** A checker that reads a renamed file goes red.
  A plant whose target text moved says *"could not plant"* instead of
  passing. Both behaviours turned a silent collision into a visible one.
- **Worktrees.** Both `canonical-gaps` branches were developed in
  isolation and merged cleanly in history — the divergence was entirely
  in uncommitted working trees, not in commits.
- **Byte comparison before discarding.** Hashing each dirty file against
  the branch showed 13 of 19 were the *same work*, which turned "whose
  changes win" into "this is one thing, mid-flight".
- **Parking instead of deleting.** Nested `.git` directories, untracked
  files and working-tree patches were moved aside rather than removed,
  and were verified pushed or byte-identical first.

---

## Decided 2026-09-15

All four were put to the owner and answered. Two became gates; two
became conventions.

| Question | Decision | Where |
|---|---|---|
| ADR id allocation | **Gate duplicates in the sweep.** Detection already worked — it moves from merge-time to commit-time, so a collision surfaces before a branch is built on it | `tooling/cpcp/check_adr_ids.py` + plant |
| Doc claims vs code | **Gate a few named counts.** Narrow and concrete, not a general assertion language in the docs | `tooling/governance/check_doc_counts.py` + plant |
| Agent attribution | **`Co-Authored-By` trailer per agent**, as fleet convention. Zero infrastructure, greppable, survives two agents adopting one prose style | convention |
| Plan ownership | **`owner:` in plan front-matter, no gate yet** | convention |

### The count gate covers one shape only

A claim in prose whose truth is a number the tree already knows. Five
claims are registered: the task kinds `Ui::Catalog` ships, and the pod
container count in four documents. It fails closed twice — a counter
that finds zero is an error, and **a claim whose pattern no longer
matches is an error**, because a reworded document would otherwise make
the gate stop checking without saying so.

### Attribution had to be decided before ownership could be applied

`owner:` was set on the four plans authored in this session. It was
**not** set on the other eleven, and the reason is the attribution
problem two rows above: `git log --diff-filter=A` reports the same
author for every plan in the tree, so there is no record to recover.
Assigning owners by inference would fabricate exactly the record the
field exists to hold.

Those eleven are listed below for their owners to claim. An empty
`owner:` is an honest unknown; a guessed one is worse than none.

```
plan_cpcp_agentic_ui      plan_ornith              plan_procedure_repo
plan_resource_cli         plan_self_learn          plan_sharedai_canvas
plan_vv_dependency_orch   plan_vv_medallion_memory plan_vv-bpmn-bbo
plan_vv-code-search       plan_vv-sdlc
```

The trailer convention starting now is what makes the next five days
attributable. It does nothing for the last five.
