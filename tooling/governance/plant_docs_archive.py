#!/usr/bin/env python3
"""Plants for the docs-archive convention. Empty CHECK_ROOT, broken index
link, missing archive README. Restores files.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/governance/check_docs_archive.py"
INDEX = ROOT / "docs/architecture/COVERAGE_GAPS.md"
README = ROOT / "docs/archive/README.md"


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

    orig = INDEX.read_text(encoding="utf-8")
    try:
        planted = orig.replace("../archive/findings/", "../archive/missing/", 1)
        if planted == orig:
            ok = note(rows, "link-edit", False, "could not plant") and ok
        else:
            INDEX.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "broken-link-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        INDEX.write_text(orig, encoding="utf-8")

    if README.is_file():
        saved = README.read_bytes()
        try:
            README.unlink()
            r = run()
            ok = note(rows, "missing-readme-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
        finally:
            README.write_bytes(saved)
    else:
        ok = note(rows, "readme-present", False, "README absent before planting") and ok

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant docs-archive: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
