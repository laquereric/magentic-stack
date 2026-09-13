#!/usr/bin/env python3
"""Plants for ADR 0070. Restores files."""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/pins/check_monty_pin.py"
PIN = ROOT / "upstreams/manifests/monty.pin.json"
FAKE = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"


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


def main() -> int:
    rows = []
    ok = True
    r = run()
    ok = (r.returncode == 0) and ok
    rows.append(("clean", r.returncode == 0, "exit %d" % r.returncode))
    r = run({"CHECK_ROOT": ""})
    ok = (r.returncode != 0) and ok
    rows.append(("empty-root", r.returncode != 0, "exit %d" % r.returncode))

    orig = PIN.read_text(encoding="utf-8")
    try:
        data = json.loads(orig)
        data["pinned_revision"] = FAKE
        data["reviews"] = []
        PIN.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        r = run()
        ok = (r.returncode != 0) and ok
        rows.append(("pin-move-without-review-fails", r.returncode != 0, "exit %d" % r.returncode))
    finally:
        PIN.write_text(orig, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant monty-pin: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
