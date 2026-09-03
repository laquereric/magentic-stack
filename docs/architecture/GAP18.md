# Gap 18: ROLE=bus CPCP seam (no RES)

Built at SHA of this change. Arguments the brief asked for, not assumed.

## 1. Own controller, not the engine

Stock `RpcController` still `status: :ok` at four sites. Row 49 KEEP BOTH
applies to whatever refusals bus emits (empty body, unparseable, unknown
method). Vault already left the engine for that reason.

Mounting the engine would also draw BACK's `note.create`. Bus is not a
domain writer of notes (row 73, 0056).

So: `BusCpcpController`, `POST /_cpcp/rpc` only. Same shape as vault.
Do not override `ActionController#dispatch`.

Async/non-domain does **not** change the answer. 200-on-refusal is still
the named hazard; it is just a smaller surface.

## 2. Methods

One: `bus.projection.latest`.

Retain is not an RPC. The PULL derives counts from BACK's operation
journal (no row copies) and writes `bus_projections`, then returns that
row. BACK never calls bus (row 72).

`ruby_event_store-browser` / extra verbs were not added. Fewer is better.

## 3. domain_writers: a third case

Not `all_domain`. Not `[]`. Named writes:

```
writes: ["BusProjection"]
tables: ["bus_projections"]
```

Same shape as BACKJOB's allowlist, different table. That is how the JSON
already expresses "this ROLE writes these models." BUS owns its own sqlite
on the bus-data named volume (`BUS_DB_PATH`); it mounts the domain file
read-only as the projection source. Persist still decides placement
(row 16); the shared-`DB_PATH` stand-in is retired.

## 4. Who calls it today

**Nobody.** No production client of `http://bus`. Inventing a BACK
fire-and-forget would make BACK depend on bus being up or on swallowing
errors — row 72 is cleaner if BACK does not dial at all.

An unbuilt caller is recorded rather than invented.

## 0050 stale text

0050's body still says BUS implements RES. Owner declined RES and said
build to the decision, not that sentence. This build is the AR-table
projection, not RES. If that sentence were allowed to change the build,
we would have stopped. We did not: the owner already called it.
