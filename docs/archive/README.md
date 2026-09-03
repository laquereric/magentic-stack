# Archive: deliberation and closed findings

Live docs stay lean; history stays readable. Nothing here is deleted.

* `reviews/` — session memos (Manus/grok/Claude deliberation). Dated
  reasoning, not decisions. Cited from ADR prose where it mattered.
* `findings/` — scope and findings docs for CLOSED rows (GAP/ROW). The
  open scopes, pin standards, and gate inputs stay in
  `docs/architecture/`: `ROW7`, `ROW10*`, `ROW86_87`, `GAP109`,
  `ROW114`, `GAP62_PROMPT`, `GAP99`, `GAP7_ENV`, `GAP7_GRAPH`.

Rules:

* `docs/adr/` stays COMPLETE, including superseded records — the ingest
  suite answers what governs by skipping them, and that only works if
  they are present. Accepted ADRs are never edited (link-target repair
  after a move is maintenance, not a decision change).
* Links into the archive use `../archive/...` from `docs/` peers and
  `../../...` from inside the archive. `check_docs_archive.py` resolves
  every findings link in `COVERAGE_GAPS.md`.
