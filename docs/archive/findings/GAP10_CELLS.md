# Gap 10 follow-up: MIND persists the Python the LLM writes per cycle

Built at SHA of this change. The LLM runs Jupyter-style code cells
(`LLMOutput` events) in NOOA's REPL; this makes those cells first-class
at pod level in both places they belong.

## 1. Durable: the NOOA event store (verified, not invented)

`Agent.__init__` builds its `EventManager` on the storage backend, so
with `DB_PATH` bound every turn event — including code cells — already
reaches `mind-nooa-data.sqlite`. Verified against the real classes in
the image: `LLMOutput(content=...)` extracts, `Message` does not.
Retrieval one-liner (runner, needs no model):

```python
agent.events.query(type="LLMOutput")
```

Unbound runs (`:memory:` default) still evaporate — honest dev
ephemerality, same as inference memory itself. No new store was created
(row 48 would have owned its placement); nothing here bypasses BACK,
whose admission stays the only truth.

## 2. Visible: retained reading + observation (built)

* `mind_cells.py` (stdlib-only): `from_events` over duck-typed events →
  bounded `[{index, sha256, chars, preview}]` (16 cells, 240 chars);
  `from_agent(agent, skip)` scopes to the new cycle — a manager that
  replays backend history cannot attribute old cells forward
  (chronological order makes the positional skip sound); everything
  fails soft to `[]` so a missing list never fails the cycle.
* Harness extracts after every `read_session`, prints counts in
  `mind_observation.python`, and retains the bounded list — so
  `mind.reading.latest` now serves `python_cells` (additive; unrecorded
  shape unchanged).
* Cells are DATA: the gate asserts no `exec(`/`eval(`/`compile(` in the
  module, and nothing executes them anywhere in this tree.

## 3. Gates

* `check_mind_cells.py` (17 examined): executes extraction on fixtures
  (exact sha/chars/preview, filtering, bounds, summarize, skip,
  fail-soft), asserts harness wiring tokens, Dockerfile shipment.
  Plants: unwired harness, unshipped module, framework import.
* Dockerfile `COPY`s the module; census needs no entry (no `_cpcp/rpc`
  token); seam authority untouched (no new seam).

## 4. Traps found by running

* **Fixture class names must BE the event names.** Duck-typing keys on
  `type(e).__name__`; `SimpleNamespace` fakes silently extract nothing.
  Name fakes `LLMOutput` (or use the real classes, as the image run did).
* **Comment prose defeats naive plants** (established before): the
  Dockerfile plant needed comment-stripping, same class as the
  entrypoint `db:prepare` catch.
* **Call-scoping is positional.** Sound only because EventsApi promises
  chronological order; if NOOA ever reorders, the skip misattributes.
  Re-check against the pinned NOOA on every pin move.
