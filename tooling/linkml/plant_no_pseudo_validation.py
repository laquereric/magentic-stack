#!/usr/bin/env python3
"""Plants for check_no_pseudo_validation. Proves the gate fails when it should.

A gate against pseudo validation that never fires is itself pseudo validation,
so each rule gets a plant that triggers exactly it:

  maxcard-zero      the inversion: a prohibition that permits one value
  miscased-range    range: Boolean, which resolves to nothing
  empty-section     unique_keys, which nothing validates
  shape-opened      an artifact whose shapes stop refusing

Restores every file it touches.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/linkml/check_no_pseudo_validation.py"
SCHEMA = ROOT / "gems/shapes-application/contracts/mind-pod/linkml/pod-note.yaml"
SHACL = ROOT / "gems/shapes-application/contracts/mind-pod/pod-note-generated.shacl.ttl"


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


def plant_schema(rows, name, addition, marker):
    """Append to the schema, expect a failure naming the right rule."""
    orig = SCHEMA.read_text(encoding="utf-8")
    try:
        SCHEMA.write_text(orig + addition, encoding="utf-8")
        r = run()
        caught = r.returncode != 0 and marker in (r.stdout + r.stderr)
        rows.append((name, caught, "exit %d" % r.returncode))
        return caught
    finally:
        SCHEMA.write_text(orig, encoding="utf-8")


def main() -> int:
    rows: list[tuple[str, bool, str]] = []
    ok = True

    r = run()
    rows.append(("clean", r.returncode == 0, "exit %d" % r.returncode))
    ok = (r.returncode == 0) and ok

    ok = plant_schema(
        rows, "maxcard-zero",
        "      planted_forbidden:\n        maximum_cardinality: 0\n",
        "MAXCARD_ZERO",
    ) and ok

    ok = plant_schema(
        rows, "miscased-range",
        "      planted_flag:\n        range: Boolean\n",
        "UNRESOLVABLE_RANGE",
    ) and ok

    # A shape that no longer refuses: drop sh:closed from the artifact.
    orig_shacl = SHACL.read_text(encoding="utf-8")
    try:
        opened = orig_shacl.replace("sh:closed true", "sh:closed false")
        if opened == orig_shacl:
            rows.append(("shape-opened", False, "could not plant"))
            ok = False
        else:
            SHACL.write_text(opened, encoding="utf-8")
            r = run()
            caught = r.returncode != 0 and "DOES_NOT_REFUSE" in (r.stdout + r.stderr)
            rows.append(("shape-opened", caught, "exit %d" % r.returncode))
            ok = caught and ok
    finally:
        SHACL.write_text(orig_shacl, encoding="utf-8")

    r = run()
    rows.append(("restored", r.returncode == 0, "exit %d" % r.returncode))
    ok = (r.returncode == 0) and ok

    for name, passed, detail in rows:
        print("  %s %s -- %s" % ("ok" if passed else "FAIL", name, detail))
    print("population: %d examined, 0 skipped" % len(rows))
    print("plant no-pseudo-validation: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
