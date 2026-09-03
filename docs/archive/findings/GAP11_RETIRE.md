# Gap 11, slice C: `:13001` retired

Built at SHA of this change. Scope was [`ROW11.md`](ROW11.md) slice C
(the display it was conditioned on shipped in slice B). Slice D remains.

## 1. What was built

* Both composes: `ports: [ "13001:8790" ]` deleted; `expose` gains
  `8790` beside `8789` (pod-internal UI plane for config-admin's
  display). Loopback healthcheck unchanged. No host port anywhere on
  switch; the pod publishes `:13000`/`:13002`/`:13003` only.
* `check_switchyard_algorithms.py`: the published-8790 assertion
  inverted — any `ports:` on the switch service now fails (the old
  4000-specific check stays as documentation). Plant adds both ports
  back (renamed `publish-fails`).
* Live docs updated: compose headers, `server.mjs` plane comment,
  ContainerTopology (edge dropped, display edge added, port counts,
  key custody), SWITCHYARD.md, adapter README, GAP46 re-placement,
  client/controller comments. Frozen records untouched: 0050 (ADR),
  GAP5/GAP61 findings, POD_PHASE0_INVENTORY (investigate-only),
  Manus reviews.

## 2. Gates

* Sweep green including the inverted assertion and renamed plant.
* Switch node tests unaffected (ephemeral ports, never `:13001`
  except the Origin-rejection test value, which is just a string).

## 3. What this does not do

* Slice D (row 83 cache-attest verdict).
* Removing the UI plane itself (`:8790` stays for config-admin and the
  healthcheck).
* Touching the data plane, the pin, or the bind mount.
