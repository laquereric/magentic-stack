# Gap 11, slice D (verdict): no cache to reuse, so nothing to attest

Decided 2026-09-03 from `5f89bf0`. Not a build — a measured verdict with
a tripwire. Rows 83, 84, 85 close as dormant on the strength of it.

## 1. Measured: no block-reuse consumer exists

* Our code: no `kv_cache` / `KVCache` / `prefix_cache` / block-reuse
  machinery in `runtimes/mind-pod/mind/*.py` (harness, agent, seam,
  cells) or `runtimes/switch/*.mjs` + UI. The only "cached" in our tree
  is an idempotency comment (a receipt, not a block).
* Pinned NOOA: `kv_cache`/`prefix_cache` appear only in comments about
  provider-side automatic prefix caching (vendor behavior, billed, not
  operated by us). Agent-state snapshots (`save_snapshot` /
  `restore_snapshot`) exist and are the sanctioned stop/restore path
  (row 82) — snapshots are whole-state durability, not cross-execution
  block reuse, and this verdict does not touch them.
* Pinned Switchyard: `cache_eligibility.rs` tracks *theoretical* hit
  rate as statistics behind `SWITCHYARD_THEORETICAL_CACHE`. Token
  "cached" counters are observability, not admission (SWITCHYARD.md §5
  already says so).

A gate built today would have no consumer to bind and no fixture that
can exercise it — speculative machinery, untestable by construction.
The decisions stand as constraints instead: router owns reuse (83),
admission contract (84), consumer-bound (85), refuse-by-default always.

## 2. Tripwire, not machinery

`check_no_kv_cache.py` fails the sweep the day block-reuse tokens
appear in our code. That failure IS the reactivation: build the
admission contract then, with a real consumer to bind it to. Pin moves
re-check `cache_eligibility.rs` by hand (0061 `reviews[]` already forces
a human look at every move; a coded assertion over upstream internals
would break on refactors unrelated to us).

## 3. What this does not do

* Close row 82 (stop/restore roadmap — separate, still decided-unbuilt).
* Forbid snapshots (sanctioned by 82).
* Attest anything about vendor-side prefix caching (unobservable from
  here; billed through, never admitted as truth).
* Touch the data plane, the pin, or any standing gate.
