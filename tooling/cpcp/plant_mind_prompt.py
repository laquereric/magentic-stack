#!/usr/bin/env python3
"""Plants for gap 99. Empty CHECK_ROOT, a forbidden claim, and a
stale pin must fail. Restores files.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/cpcp/check_mind_prompt.py"
SRC = ROOT / "runtimes/mind-pod/mind/mind_agent.py"
PIN = ROOT / "tooling/cpcp/mind_prompt_pin.json"


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

    orig = SRC.read_text(encoding="utf-8")
    try:
        planted = orig.replace(
            "You may carry inference memory",
            "You may carry durable memory",
            1,
        )
        if planted == orig:
            ok = note(rows, "forbid-edit", False, "could not plant durable memory") and ok
        else:
            SRC.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "forbidden-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        SRC.write_text(orig, encoding="utf-8")

    pin_orig = PIN.read_text(encoding="utf-8")
    try:
        data = json.loads(pin_orig)
        data["sha256"] = "0" * 64
        PIN.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        r = run()
        ok = note(rows, "stale-pin-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        PIN.write_text(pin_orig, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant mind-prompt: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
