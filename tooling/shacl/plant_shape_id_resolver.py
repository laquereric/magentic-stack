#!/usr/bin/env python3
"""Plants for gap 22. Second mapping copy, inline table, skipped resolve.
Restores files. Does not UPDATE stored shape_id.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/shacl/check_shape_id_resolver.py"
RESOLVER = ROOT / "gems/rails-osi-level-8/lib/rails_osi_level_8/shape_id.rb"
PROJECTIONS = ROOT / "gems/rails-osi-level-8/lib/rails_osi_level_8/projections.rb"
SECOND = ROOT / "gems/rails-osi-level-8/data/osi_example_successors.json"
MAPPING = ROOT / "tooling/shacl/osi_example_successors.json"


def run(env=None):
    e = os.environ.copy()
    e.pop("CHECK_ROOT", None)
    if env:
        e.update(env)
    return subprocess.run(
        [sys.executable, str(CHECKER)],
        cwd=str(ROOT),
        env=e,
        capture_output=True,
        text=True,
    )


def note(rows, name, passed, detail):
    rows.append((name, passed, detail))
    return passed


def main():
    rows = []
    ok = True
    r = run()
    ok = note(rows, "clean", r.returncode == 0, "exit %d" % r.returncode) and ok
    r = run({"CHECK_ROOT": ""})
    ok = note(rows, "empty-root", r.returncode != 0, "exit %d" % r.returncode) and ok

    SECOND.parent.mkdir(parents=True, exist_ok=True)
    try:
        SECOND.write_text(MAPPING.read_text(encoding="utf-8"), encoding="utf-8")
        r = run()
        ok = note(rows, "second-copy-fails", r.returncode != 0,
                  "exit %d" % r.returncode) and ok
    finally:
        if SECOND.exists():
            SECOND.unlink()

    orig = RESOLVER.read_text(encoding="utf-8")
    try:
        planted = orig.replace(
            'iri = stored.to_s',
            'iri = stored.to_s\n      TABLE = {"https://osi.example/shapes/P1NoteCreateEffectShape" => "x"}',
            1,
        )
        if planted == orig:
            ok = note(rows, "inline-edit", False, "could not plant") and ok
        else:
            RESOLVER.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "inline-table-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        RESOLVER.write_text(orig, encoding="utf-8")

    orig_p = PROJECTIONS.read_text(encoding="utf-8")
    try:
        planted = orig_p.replace("row.merge(ShapeId.resolve(row[\"shape_id\"]))", "row", 1)
        if planted == orig_p:
            ok = note(rows, "skip-edit", False, "could not plant") and ok
        else:
            PROJECTIONS.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "skip-resolve-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        PROJECTIONS.write_text(orig_p, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant shape-id-resolver: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
