#!/usr/bin/env python3
"""Plants for gap 110. A NodeShape that never reaches the inventory must fail.
Empty CHECK_ROOT must fail. Restores files.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/shacl/check_shape_quarantine.py"
TTL = ROOT / "gems/shapes-level-8/bundles/contextframe.shacl.ttl"
PLANTED = """
cf:PlantedOrphanShape a sh:NodeShape ;
  sh:targetClass cf:PlantedOrphan .
"""


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

    orig = TTL.read_text(encoding="utf-8")
    try:
        TTL.write_text(orig + PLANTED, encoding="utf-8")
        r = run()
        ok = note(rows, "new-nodeshape-never-inventoried-fails", r.returncode != 0,
                  "exit %d" % r.returncode) and ok
    finally:
        TTL.write_text(orig, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant shape-quarantine: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
