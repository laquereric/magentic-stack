# Gap 92: the ADR corpus did not pass its own ingest

Three failures, three fixes. The ingest assertion was not relaxed.

## 1. SUBJECT_KINDS — extend, do not reclassify

`Vocabulary::SUBJECT_KINDS` was `%w[protocol profile gem tooling repo]`.
The corpus also uses `topology` (5), `doctrine` (5), and `data` (2):
twelve accepted ADRs from 0046 through 0058, including 0058 written in
this session. **0001 and 0002 are already permitted** (`tooling`, subject
`repo`). They were not the drift.

**Choice (a) extend the enum.** Same reason `repo` was added for ADR 0038:
without the kind, the decision can only be recorded by mislabelling its
subject. Topology is container/ROLE layout, not a gem and not the clone.
Doctrine is a standing rule that crosses components. Data is store truth
(the journal vs a column). Folding all twelve into `repo` would make
"which repo decisions" a junk drawer and hide the questions the closed
vocabulary exists to answer.

Reclassify (b) would also edit twelve accepted records' `subject_kind`.
Frontmatter is not the body digest, so it would save — and still be the
wrong label.

## 2. `:constraint` — the ADRs, not the chain

`Chain.break_at` returns `:constraint` when `enforced_by` is empty. That
is the middle link of *decision → constraint → code*. The assertion
`expect(breaks).to be_empty` is the fitness function; it was not
weakened.

0041, 0045 and 0051 ingested (kind `protocol`) with `enforced_by: []`.
0046–0058 failed ingest on kind first, so they never reached the chain
report. Once the kinds are valid they would have been the same break.

The wrong side was the files: accepted ADRs that named no mechanism.
`enforced_by` now points at existing gates/compose/specs that actually
guard the decision as built today. Unbuilt targets (MIND seam, ROLE=shape,
BUS, LOG, DB_PATH-as-effect) name the live stand-in (boundary test,
catalog, CPCP spec, refusal log, compose `DB_PATH`), not a file that
does not exist.

## 3. CI

`bin/spec-all` already ran `gems/mmg-adr` and was red. Nothing *named*
the corpus as a gate, which is how `document_spec` alone looked green.
`.github/workflows/adr-ingest.yml` runs the full mmg-adr suite on
`docs/adr/**` and `gems/mmg-adr/**`. ADR 0014 now lists `ingest_spec.rb`.
