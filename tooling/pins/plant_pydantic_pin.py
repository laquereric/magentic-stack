#!/usr/bin/env python3
"""Plants for the pydantic pin. Restores files. Empty CHECK_ROOT fails."""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/pins/check_pydantic_pin.py"
REQ = ROOT / "runtimes/mind-pod/mind/requirements.txt"
PIN = ROOT / "upstreams/manifests/pydantic.pin.json"


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


def main() -> int:
    rows = []
    ok = True
    r = run()
    ok = note(rows, "clean", r.returncode == 0, "exit %d" % r.returncode) and ok
    r = run({"CHECK_ROOT": ""})
    ok = note(rows, "empty-root", r.returncode != 0, "exit %d" % r.returncode) and ok

    orig = REQ.read_text(encoding="utf-8")
    try:
        REQ.write_text(orig.replace("pydantic==2.13.5", "# pydantic unpinned\n"), encoding="utf-8")
        r = run()
        ok = note(rows, "req-unpinned-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        REQ.write_text(orig, encoding="utf-8")

    orig_p = PIN.read_text(encoding="utf-8")
    try:
        PIN.write_text(orig_p.replace("2.13.5", "0.0.0", 1), encoding="utf-8")
        r = run()
        ok = note(rows, "pin-drift-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        PIN.write_text(orig_p, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant pydantic-pin: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
