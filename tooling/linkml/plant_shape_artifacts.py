#!/usr/bin/env python3
"""Plants for check_shape_artifacts. Proves the gate fails when it should.

Four plants, one per thing the gate claims:
  clean            passes as-is
  edited-artifact  a hand-edited reified artifact is caught
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

    r = run()
    ok = note(rows, "restored", r.returncode == 0, "exit %d" % r.returncode) and ok

    for name, passed, detail in rows:
        print("  %s %s -- %s" % ("ok" if passed else "FAIL", name, detail))
    print("population: %d examined, 0 skipped" % len(rows))
    print("plant shape-artifacts: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
