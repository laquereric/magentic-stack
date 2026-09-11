#!/usr/bin/env python3
"""Plants for check_shape_artifacts. Proves the gate fails when it should.

Plants, one per thing the gate claims:
  clean            passes as-is
  edited-artifact  a hand-edited reified artifact is caught
  edited-pydantic  so is a hand-edit to the in-process pydantic face
  pydantic-is-closed  sh:closed reaches the model as extra="forbid"
  opened-pydantic-accepts  and removing it really does open the model
  edited-schema    a changed schema with stale artifacts is caught
  prod-generates   a runtime that imports linkml is caught

Restores every file it touches.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/linkml/check_shape_artifacts.py"
ARTIFACT = ROOT / "tooling/linkml/generated/pod-note.ts"
PYDANTIC = ROOT / "tooling/linkml/generated/pod_note_pydantic.py"
SCHEMA = ROOT / "gems/shapes-application/contracts/mind-pod/linkml/pod-note.yaml"
RUNTIME_PROBE = ROOT / "runtimes/mind-pod/app/lib/_plant_linkml_probe.py"


def run():
    e = os.environ.copy()
    e.pop("CHECK_ROOT", None)
    return subprocess.run(
        [sys.executable, str(CHECKER)],
        cwd=str(ROOT),
        env=e,
        capture_output=True,
        text=True,
        timeout=900,
    )


def note(rows, name, passed, detail):
    rows.append((name, passed, detail))
    return passed


def main() -> int:
    rows: list[tuple[str, bool, str]] = []
    ok = True

    r = run()
    ok = note(rows, "clean", r.returncode == 0, "exit %d" % r.returncode) and ok

    # A hand-edited artifact stops tracing to its source.
    orig_a = ARTIFACT.read_text(encoding="utf-8")
    try:
        ARTIFACT.write_text(orig_a + "\nexport interface Planted { x: string }\n", encoding="utf-8")
        r = run()
        ok = note(rows, "edited-artifact", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        ARTIFACT.write_text(orig_a, encoding="utf-8")

    # The pydantic face is an artifact like any other. It gets its own plant
    # rather than riding on the TypeScript one because it is the face
    # PySparqlFun consumes IN PROCESS (docs/architecture/SparqlFun.md), which
    # makes a hand-edit here cheaper to do and harder to notice: a stray field
    # added to a pydantic model is ordinary-looking Python, not a diff in a
    # file nobody opens.
    orig_p = PYDANTIC.read_text(encoding="utf-8")
    try:
        PYDANTIC.write_text(
            orig_p + "\n\nclass Planted(ConfiguredBaseModel):\n    x: str\n", encoding="utf-8"
        )
        r = run()
        ok = note(rows, "edited-pydantic", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        PYDANTIC.write_text(orig_p, encoding="utf-8")

    # CLOSEDNESS SURVIVES THE GENERATOR. gen-pydantic emits
    # `extra = "forbid"`, which is how sh:closed reaches the in-process face;
    # the TypeScript face needed a post-processing hook for the equivalent
    # (bind_typescript_enums) and this one does not. That is a property of the
    # ARTIFACT, so it is proved here rather than asserted in a comment: strip
    # the forbid and a model that must refuse an unknown property stops
    # refusing it.
    def closed_survives() -> tuple[bool, str]:
        import importlib.util  # noqa: PLC0415

        spec = importlib.util.spec_from_file_location("_plant_pyd", PYDANTIC)
        module = importlib.util.module_from_spec(spec)
        try:
            spec.loader.exec_module(module)
            module.Note(id="1", title="t", created_at="2026-01-01T00:00:00", surprise="x")
        except Exception as exc:  # refused is the pass
            return True, type(exc).__name__
        return False, "extra property accepted"

    accepted_ok, detail = closed_survives()
    ok = note(rows, "pydantic-is-closed", accepted_ok, detail) and ok

    try:
        PYDANTIC.write_text(orig_p.replace('extra = "forbid"', 'extra = "allow"'), encoding="utf-8")
        opened_ok, detail = closed_survives()
        ok = note(rows, "opened-pydantic-accepts", not opened_ok, detail) and ok
    finally:
        PYDANTIC.write_text(orig_p, encoding="utf-8")

    # A changed schema with un-regenerated artifacts.
    orig_s = SCHEMA.read_text(encoding="utf-8")
    try:
        SCHEMA.write_text(orig_s + "\n# planted drift\n", encoding="utf-8")
        r = run()
        ok = note(rows, "edited-schema", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        SCHEMA.write_text(orig_s, encoding="utf-8")

    # A runtime that generates its own shapes.
    try:
        RUNTIME_PROBE.parent.mkdir(parents=True, exist_ok=True)
        RUNTIME_PROBE.write_text("import linkml  # planted\n", encoding="utf-8")
        r = run()
        ok = note(rows, "prod-generates", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        RUNTIME_PROBE.unlink(missing_ok=True)

    # A generated query with a prefix it never declares.
    QUERY = ROOT / "tooling/linkml/generated/pod-note-queries/CHECK_required_Note_title.rq"
    orig_q = QUERY.read_text(encoding="utf-8")
    try:
        QUERY.write_text("\n".join(l for l in orig_q.splitlines() if not l.startswith("PREFIX rdf:")) + "\n", encoding="utf-8")
        r = run()
        ok = note(rows, "query-prefix-stripped", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        QUERY.write_text(orig_q, encoding="utf-8")

    # A query the schema no longer produces.
    STALE = QUERY.parent / "CHECK_planted_stale.rq"
    try:
        STALE.write_text(orig_q, encoding="utf-8")
        r = run()
        ok = note(rows, "query-stale", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        STALE.unlink(missing_ok=True)

    # The Oxigraph check itself: it must reject what the store rejects. This
    # runs against freshly generated queries, so it cannot be planted through a
    # committed artifact -- a broken committed query fails the byte comparison
    # first and would never reach the parser.
    sys.path.insert(0, str(ROOT / "tooling/linkml"))
    try:
        import importlib.util

        spec = importlib.util.spec_from_file_location("gs", ROOT / "tooling/linkml/generate_shapes.py")
        gs = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(gs)
        undeclared = "SELECT ?s WHERE { ?s rdf:type <urn:x> . }"
        declared = "PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>\n" + undeclared
        rejects = gs.sparql_accepted_by_oxigraph(undeclared) is not None
        accepts = gs.sparql_accepted_by_oxigraph(declared) is None
        ok = note(rows, "oxigraph-rejects-undeclared", rejects and accepts,
                  "rejects=%s accepts=%s" % (rejects, accepts)) and ok
        fixed, unfixable = gs.declare_missing_prefixes(undeclared)
        ok = note(rows, "prefix-injection", not unfixable and "PREFIX rdf:" in fixed,
                  "unfixable=%s" % unfixable) and ok
    except Exception as exc:
        ok = note(rows, "oxigraph-rejects-undeclared", False, "%s: %s" % (type(exc).__name__, exc)) and ok

    r = run()
    ok = note(rows, "restored", r.returncode == 0, "exit %d" % r.returncode) and ok

    for name, passed, detail in rows:
        print("  %s %s -- %s" % ("ok" if passed else "FAIL", name, detail))
    print("population: %d examined, 0 skipped" % len(rows))
    print("plant shape-artifacts: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
