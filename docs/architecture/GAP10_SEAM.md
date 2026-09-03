# Gap 10, slice 2: the MIND seam serves (stdlib, gated)

Built at SHA of this change. Scope was [`ROW10.md`](ROW10.md), method set
[`ROW10_SLICE1.md`](ROW10_SLICE1.md) (approved). Slices 3–5 remain.

## 1. What was built

`runtimes/mind-pod/mind/mind_seam.py` (stdlib only: `http.server` +
`json` + `hashlib` + `threading`): exactly the 3 approved methods on
`POST /_cpcp/rpc`, 404 otherwise. `MIND_CALLERS` allowlist
(`{id: {token, operations}}`), 401/403/400/429/500 all non-200 plus
envelope (row 49 KEEP BOTH). `latest` serves the retained reading or
`recorded:false`; `request` validates shape (iri, non-bool
non-negative generation, session id, bounded rows) and admits to a
bound-32 FIFO (`mind_queue_full` at 429); `up` reports readiness + NOOA
version (guarded import — the seam never drives cognition or storage, no
`urllib`, no `BACK_URL`, no sqlite).

Harness: seam on a daemon thread (`MIND_SEAM_PORT`, default 8091),
reading retained after every propose, one admitted request per cycle
ahead of the BACK poll. Empty-queue behaviour is byte-identical
(observation print untouched). An unbindable seam logs `mind_seam_error`
and cognition continues — the seam fails closed (refuses everything
unconfigured), the process does not (no shell exists for a boot script;
the cycle must not depend on seam configuration).

Deploy: `EXPOSE 8091` in image metadata, `expose` (never `ports`) +
`MIND_CALLERS` in both composes, seam authority live row (adapter
surface, not a writer). BACK-pull gate, conformance, and prompt re-audit
are slices 3–5.

## 2. Gates

* `check_mind_seam.py` (21 examined): executes the real dispatch on a
  bare interpreter — method triple, stdlib-only top-level imports,
  function-local `nooa` confined to version reporting, no BACK dialing,
  full refusal matrix, queue bound, unconfigured-500, Dockerfile +
  compose wiring. Plants: 4th method, framework import, BACK-dial
  import, published port.
* Census: seam as server/mind. `cpcp_callers` bidirectional match holds.

## 3. Live proof (isolated, wiped)

* Boot lines unchanged plus `mind_seam_boot`; cycle errors continue
  alongside. RPC battery green: up/latest-empty/admit/400s/401.
* Queue pickup observed: BACK-poll errors ceased after admission (cycle
  took the queued branch); cognition then blocked on the unreachable
  model — identical to the existing poll path's behaviour, so no new
  failure mode. Slice 3 (timeouts/cancellation) owns that stall.

## 4. Traps found by running

* **Pipe-masked exits.** `cmd | tail; echo $?` reports tail's status.
  The gate "passed" twice while failing (function-local `nooa` import).
  Check tool exits unpiped or with `pipefail`.
* **Distroless has no shell and no second binary name.** `docker exec`
  debugging is limited to the image ENTRYPOINT binary; live memory is
  uninspectable — reason from logs and seam reads, not from inside.
* **IMAGE ENTRYPOINT swallows `docker run` commands** (established
  earlier): override `--entrypoint` to run anything but the server.

## Slice 4 — prompt re-audit (done, pin updated)

* Added WHAT OTHERS CAN ASK OF ME to the class docstring (readings +
  written Python retained and served as leads; proposing unchanged).
  Re-audited sentence by sentence against GAP62 verdicts: all new
  claims TRUE, no forbidden string returns, all required strings kept.
  Pin updated (sha `eabbce82`, 2002 chars); `check_mind_prompt.py` +
  plants green. (One misstep caught: the section first landed in the
  *method* docstring — the task prompt, not the pinned system prompt —
  and was moved before pinning.)

## Slice 5 — BACK completes with MIND stopped

* Static: `check_back_no_mind_dial.py` fails the sweep on any BACK-side
  reference to the mind seam (port, methods, module). A future pull lands
  together with an amendment here requiring bounded timeout + fallback.
* Live: BACK alone on an isolated network served `note.list` ok — zero
  MIND folk present (the `nomind-back` name matched its own grep; no mind
  container existed).
