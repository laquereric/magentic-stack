# Gap 10, slice 3: cross-seam conformance passes

Ran 2026-09-03 from `ab047b8`. Runner:
`tooling/cpcp/conformance_seams.py`
(`BACK_URL`, `MIND_URL`, `MIND_TOKEN` required — missing any fails, never
skips). 10/10 PASS against live BACK + MIND on isolated fixtures (wiped).

## 1. What it asserts (discipline, not parity)

The seams serve different methods by design. Shared: every response is
an envelope (`ok`, `jsonrpc`, `id` echo); refusals name a reason from
each seam's documented taxonomy. Profiles differ and both hold — BACK
always HTTP 200 (row 49), MIND status-per-refusal (row 49 KEEP BOTH).

| Fixture | BACK | MIND |
|---|---|---|
| unknown method | 200 `unknown_operation` | 400 `unknown_operation` |
| empty body | 200 (collapses, see §2) | 400 `unparseable_json` |
| garbage body | 200 (collapses, see §2) | 400 `unparseable_json` |
| envelope + id echo | ok | ok + `ready` |
| auth | n/a (no callers) | 401 unauthenticated |
| latest unrecorded | n/a | `recorded:false` |

## 2. Observed: BACK collapses parse failures

`request_body.rb` distinguishes `empty_body` / `unparseable_json`, but
the live seam answers both (and any garbage) as `unknown_operation`
with `id:null`. Stable and gated here as measured — not fixed here
(fixing the controller's parse path is BACK surgery, out of slice 3).
Reason nests under `error` on BACK vs flat on the hand-rolled seams;
both shapes are asserted as-documented, not unified.

## 3. Not yet wired

CI (`boundary-conformance.yml` Gate 1) does not run this battery — the
runner needs two live URLs, which sweep jobs must not depend on.
Ready-to-apply step for Part C (after BACK is up, before `down -v`):

```yaml
- name: 'Part C2 - cross-seam conformance (BACK + MIND envelopes)'
  working-directory: runtimes/mind-pod
  run: |
    CF="-f docker-compose.yml -f test/docker-compose.ci.yml"
    docker compose $CF up -d --build mind
    BACK_URL=http://localhost:3000 MIND_URL=http://localhost:8091 \
      MIND_TOKEN="$MIND_CONF_TOKEN" \
      python3 ../../tooling/cpcp/conformance_seams.py; ec=$?
    docker compose $CF down -v
    exit $ec
```

Notes: mind must be published to the runner (CI overlay maps the port;
production never does); `MIND_CONF_TOKEN` is a CI secret matching a
throwaway `MIND_CALLERS` on the mind service (conformance caller only).
Not applied here — workflows are not edited without a runner to prove
them on. Remaining row-10 work: this wiring, nothing else.
