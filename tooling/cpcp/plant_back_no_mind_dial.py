#!/usr/bin/env python3
"""Plants for row 10 slice 5. Empty CHECK_ROOT, BACK dials the mind seam.
Restores files.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/cpcp/check_back_no_mind_dial.py"
CLIENT = ROOT / "runtimes/mind-pod/app/app/services/back_cpcp_client.rb"


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

    orig = CLIENT.read_text(encoding="utf-8")
    try:
        CLIENT.write_text(orig + '\n# planted: MIND_SEAM_URL = "http://mind:8091"\n', encoding="utf-8")
        r = run()
        ok = note(rows, "back-dials-mind-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        CLIENT.write_text(orig, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant back-no-mind-dial: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
