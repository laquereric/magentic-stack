#!/usr/bin/env python3
"""Plants for gap 61. Empty CHECK_ROOT, a 13000/_cpcp curl, and a
missing Makefile overlay must fail. Restores files.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/compose/check_host_cpcp.py"
QUICK = ROOT / "QUICKSTART.md"
MAKE = ROOT / "Makefile"


def run(env=None) -> subprocess.CompletedProcess:
    e = os.environ.copy()
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

    orig_q = QUICK.read_text(encoding="utf-8")
    try:
        QUICK.write_text(orig_q + "\ncurl http://localhost:13000/_cpcp/up\n", encoding="utf-8")
        r = run()
        ok = note(rows, "13000-cpcp-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        QUICK.write_text(orig_q, encoding="utf-8")

    orig_m = MAKE.read_text(encoding="utf-8")
    try:
        planted = orig_m.replace("test/docker-compose.ci.yml", "test/docker-compose.demo.yml")
        if planted == orig_m:
            ok = note(rows, "overlay-edit", False, "could not plant missing overlay") and ok
        else:
            MAKE.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "missing-overlay-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        MAKE.write_text(orig_m, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant host-cpcp: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
