#!/usr/bin/env python3
"""Plants for row 70. Empty CHECK_ROOT, monad dep, sentinel idiom.
Restores files.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/cpcp/check_no_sentinels.py"
GEMFILE = ROOT / "Gemfile"
SEAM = ROOT / "runtimes/mind-pod/mind/mind_seam.py"


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

    orig_g = GEMFILE.read_text(encoding="utf-8")
    try:
        GEMFILE.write_text(orig_g + '\ngem "dry-monads"\n', encoding="utf-8")
        r = run()
        ok = note(rows, "monad-dep-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        GEMFILE.write_text(orig_g, encoding="utf-8")

    orig_s = SEAM.read_text(encoding="utf-8")
    try:
        SEAM.write_text(orig_s + "\n_MISSING = object()\n", encoding="utf-8")
        r = run()
        ok = note(rows, "sentinel-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        SEAM.write_text(orig_s, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant no-sentinels: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
