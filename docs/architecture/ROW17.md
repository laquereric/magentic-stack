# Row 17 — should we adopt `rails_event_store` at all

Measured 2026-09-03 from `14385f039587a1a35d4b67455d9b5c20ae01ced0`.
**Design only. Not built. No Gemfile change.**

ADR [0050](../adr/0050-switchyard-is-the-upstream-plus-bus-and-persist-roles.md)
says `ROLE=bus` adopts RES. Rows [72](COVERAGE_GAPS.md) and
[73](COVERAGE_GAPS.md) then shrank the job: BUS is async and not in the
call path; the `OperationRequest` row and its journal **stay in BACK**.
This document asks what work is left that a plain AR table does not
already do.

No Gemfile, no bundle in this tree, no `ROLE=bus`, no migration.

---

## What is actually there (so the table is not a wish)

SHA `14385f0`. Populations named per count.

| Thing | Measured |
|---|---|
| App Gemfile direct gems | **8** (`rails`, `puma`, `sqlite3`, `rails-cpcp`, `rails-osi-level-8`, `mmg-graph`, `vv-graph`, `vv-base`). Same 8 at `7b417d0`. Test group extra: `rspec-rails`, `rack-test`. Population: `^gem ` lines in `runtimes/mind-pod/app/Gemfile`. |
| `rails_event_store` / `RailsEventStore` / `ruby_event_store` in **code or Gemfile** | **0**. |
| Same strings in the tree excluding `upstreams/` | **8 files, all docs/reviews.** Population: `rg` over the repo with `!upstreams/**`. The row's "zero hits" is true of *runtime*; it is not true of prose. |
| `ROLE=bus` in entrypoint / `role_routes.json` / `domain_writers.json` | **0**. Six live ROLEs in `entrypoint.sh`: back, front, backjob, vault, config, shape. |
| Admission journal | Table `osi_l8_operation_journal_entries`. Append-only SQLite triggers (UPDATE/DELETE abort). `event_kind` ∈ received, grounded, authorized, routed, dispatched, completed, refused. ADR 0052/0053. |
| Other durable records that are *not* that journal | `RefusalLog` JSONL (explicitly "a NEW durable record, not the operation journal"). `MemoryIdempotency` (not durable; observes `idempotency_not_durable`). |
| Research leftover | `gems/vv-graph/docs/plans/PLAN_0_93_2.md` still names RES as "the event backbone / shared truth". That is a plan, not a running store. |

The journal is append-only, ordered, and load-bearing **today**. RES
would be the 9th direct gem and the first framework-scale third-party
addition to this Gemfile.

---

## 1. What RES is, and what 72/73 leave any use for

Resolved **outside this repo** at `/tmp/res-adopt-pbJV` (`bundle lock`
only; nothing copied back). `rails_event_store` **3.1.0**, MIT.

Incremental family (not the whole Rails lock's 71 specs):

| gem | version | licence |
|---|---|---|
| `rails_event_store` | 3.1.0 | MIT |
| `ruby_event_store` | 3.1.0 | MIT |
| `ruby_event_store-active_record` | 3.1.0 | MIT |
| `ruby_event_store-browser` | 3.1.0 | MIT |
| `aggregate_root` | 3.1.0 | MIT |

What the product is: an **event repository**. It appends typed events to
streams, layers pub/sub and projections on top, and ships a browser UI
(`ruby_event_store-browser`). ContainerTopology.md:560 already recorded
that: "RES **is** a repository, not a transport."

| RES part | After 72 (async, not in-path) | After 73 (journal stays in BACK) |
|---|---|---|
| Durable event log as source of truth | Unneeded for `/_cpcp/rpc` completing | **Conflicts.** 0052: the operation journal is the only admission truth. |
| Streams | Optional grouping of *derived* metadata | BACK already sequences journal rows per `operation_request_cid`. |
| Pub/sub | The one plausible leftover: notify a side-channel that BACK finished | Can be a table poll, a file, or a queue. Not a second log. |
| Projections | Row 73: "BUS projects" | A projector can read the journal (or a metadata table BACK writes). It does not need to *own* events. |
| Correlation ids | CPCP `operationId` / cid already exist | — |
| Browser UI | New HTTP surface on the shared image | Gap 24's class of accident. Not required by 72/73. |
| Aggregate root | Domain aggregates live in BACK | Moving them would reopen 73. |

**Honest remainder after 72 and 73: an async retain/publish side-channel
of metadata derived from BACK.** That is a table (and maybe a notifier).
It is not an event store.

---

## 2. The do-nothing option

"Do not adopt; a table plus the existing journal is the bus."

- BACK keeps writing `osi_l8_operation_journal_entries` (0052/0053).
- BUS, when built, **reads** that journal (or a narrow metadata table
  BACK emits) and **publishes** derived facts over `ROLE=bus` `/_cpcp`.
- No second append-only ordered log of "what happened."
- No RES schema, no `event_store_events` table, no browser mount.
- Row 72 stays: `/_cpcp/rpc` on BACK completes without BUS.
- Row 18 still builds the SwitchYard CPCP endpoint on `ROLE=bus`; that
  endpoint does not need RES to exist.

This is cheaper than the named framework. It is also the only option
that does not create a second event log.

---

## 3. Cost, if we adopted anyway

| Cost | Measured / inferred |
|---|---|
| Shared image | One Rails app, one Gemfile, one image (0047 amendment 2). RES would be in **back, backjob, front, vault, config, shape** as well as bus. Route-gating keeps FRONT from *serving* a RES browser; it does not keep the gem out of FRONT's image. Population: 6 `entrypoint.sh` branches. |
| Schema | RES-AR creates its own tables. Those migrate with `db:prepare` on BACK. FRONT/vault/config/shape are DBless at boot; the gem still loads. |
| SQLite | The pod's domain store is sqlite. RES-AR can use it; concurrent subscribers and the browser were not designed around sqlite file locking. Two writers on one file is already ADR 0056's problem; a third writer (BUS appending events) is a new one. |
| Where | Row 16: persist decides WHERE the event store is written. If RES tables live in the same sqlite as the journal, "where" is `DB_PATH` and gap 48 (persist for *every* store vs only the event log) stays open. If RES gets its own file, that is a second sqlite and a second two-writer hazard. |
| Browser | `ruby_event_store-browser` is a UI. Host-publishing it would be a new port. Not in v1 of anything we have scoped. |

None of this is a reason to adopt. It is the bill.

---

## 4. ADR 0038 / adapters-sole-path — measured, not assumed

`check_boundary.py:112` `NEEDLE = 'upstreams/'`. The rule fires on a
**line of scanned source/build files** that names `upstreams/` without
also naming `upstreams/manifests`. Docs and CI are out of scope
(`:104-105`).

A `gem "rails_event_store"` line does **not** contain `upstreams/`.
The adapters-sole-path rule **does not reach a rubygem**. Confirmed by
reading the checker, not by hoping.

ADR 0038's *no-fork* clause still applies: we would consume the gem, not
vendor a fork under `upstreams/`. `gems/adapters/` stays a README until
something wraps an **upstream service**. RES is a library.

`check_language_rule.py`: default is ruby. A ruby gem in the Rails image
is the expected language. Not a violation, not an exemption.

---

## 5. The sharp question — is RES a second event log?

**Yes**, if BUS *runs RES as advertised*.

0050's amendment: BUS owns "the event log's content, streams, append
semantics, pub/sub." That is a log of events BUS appends.

0052: the operation journal is the **only** admission truth. 0053: a
complete row journals itself. Row 73: that journal **stays in BACK**.

Two append-only ordered logs of "what happened," in two ROLEs, is two
event logs. Calling the RES one "metadata" does not stop it being a
log, and RES's own doctrine is that *the event store is the source of
truth*. That doctrine cannot sit next to 0052 without someone losing.

If the honest use of RES is "pub/sub only, throw the log away," we are
paying for a repository we have forbidden to be authoritative. That is
the framework talking us into itself.

**Row 17 cannot be closed by a dependency decision that pretends this
is not a second log.** Closing it as "adopt RES" would need an ADR 0050
amendment that *retracts* "BUS owns the event log's content" or an
amendment of 0052 that *allows* a second log. This document does not
write either amendment.

---

## 6. What row 9 becomes

| Option | Row 9 (`ROLE=bus`) |
|---|---|
| **Do not adopt** | Still a real ROLE: CPCP seam (row 18) + async retain/publish of metadata derived from BACK's journal (72/73). Implemented with AR table(s) in the sqlite persist places. **No RES.** Row 17 closes as evaluated-and-declined. |
| **Adopt** | Row 9 stays blocked until the owner accepts a second event log (or amends 0050/0052). Building bus-with-RES before that is the thing row 18 is not buildable for. |
| **Adopt narrowed** (pub/sub gem only, no store) | Still a new dependency for a notifier. Does not need the RES family. Not recommended; a table poll is enough for an async side-channel. |

---

## 7. Owner decisions this document will not take

| Decision | Why it is not mine |
|---|---|
| Adopt `rails_event_store` | That is row 17's owner call. Recommendation below is not a decision. |
| Amend ADR 0050 ("BUS implements RES") | Accepted body. If the owner declines RES, 0050 needs an amendment saying BUS is the seam + projection, not an event store. Not written here. |
| Amend ADR 0052 / 0053 | Row 73 forbade moving the journal; a second log would need a new ruling, not a silent one. |
| Choose the store file / `DB_PATH` closed set | Row 39, persist (row 8/48). |
| Build `ROLE=bus` or the row 18 seam | Blocked on this decision. |
| Host-publish a RES browser | Gap 24. |

---

## 8. Recommendation

**Do not adopt.** After 72 and 73 the leftover job is an async
side-channel of derived metadata. The operation journal already is the
event log. A table plus that journal is the bus.

"Do not talk yourself into the framework because the row names it."
The row named it before 72/73 landed. Those two rows are the reason
the name no longer fits.

If the owner agrees, row 17 closes as declined; 0050 wants an amendment
(owner); row 9 becomes buildable without RES; row 18 can be briefed as
`ROLE=bus` `/_cpcp/rpc` over a table, not over an event store.

---

## 9. What this is not

- Not a Gemfile edit. Not a lockfile. `/tmp/res-adopt-pbJV` stays outside.
- Not `ROLE=bus`. Not a migration. Not row 18, 11, 40, or 41.
- Not an 0050/0052/0053 amendment.
- Not a claim that adapters-sole-path forbids a rubygem. It does not.
