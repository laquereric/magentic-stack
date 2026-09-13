#!/usr/bin/env python3
"""Plant: dropping the ADR 0001 citation or adding a pydantic-ai dep must fail."""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/pins/check_pydantic_ai_harness.py"
ADR = ROOT / "docs/adr/0001-ownership-boundary.md"
REQ = ROOT / "runtimes/mind-pod/mind/requirements.txt"


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

    orig = ADR.read_text(encoding="utf-8")
    try:
        ADR.write_text(orig.replace("pydantic-ai-harness", "some-other-harness"), encoding="utf-8")
        r = run()
        ok = note(rows, "citation-stripped-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        ADR.write_text(orig, encoding="utf-8")

    orig_r = REQ.read_text(encoding="utf-8")
    try:
        REQ.write_text(orig_r + "\npydantic-ai==2.43.0\n", encoding="utf-8")
        r = run()
        ok = note(rows, "mind-dep-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        REQ.write_text(orig_r, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant pydantic-ai-harness: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
