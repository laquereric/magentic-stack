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
REQ = ROOT / "runtimes/mind-pod/mind/requirements.txt"
DOCKER = ROOT / "runtimes/mind-pod/mind/Dockerfile"
CODEACT = ROOT / "runtimes/mind-pod/mind/mind_codeact.py"
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

    orig = PIN.read_text(encoding="utf-8")
    try:
        data = json.loads(orig)
        data["pinned_revision"] = FAKE
        data["reviews"] = []
        PIN.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        r = run()
        ok = note(rows, "pin-move-without-review-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        PIN.write_text(orig, encoding="utf-8")

    orig_req = REQ.read_text(encoding="utf-8")
    try:
        REQ.write_text(orig_req.replace("pydantic-monty==0.0.23", "# pydantic-monty unpinned\n"), encoding="utf-8")
        r = run()
        ok = note(rows, "wheel-unpinned-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        REQ.write_text(orig_req, encoding="utf-8")

    orig_df = DOCKER.read_text(encoding="utf-8")
    try:
        DOCKER.write_text(orig_df.replace("MONTY_BIN=/deps/bin/monty", "MONTY_BIN="), encoding="utf-8")
        r = run()
        ok = note(rows, "monty-bin-absent-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        DOCKER.write_text(orig_df, encoding="utf-8")

    orig_c = CODEACT.read_text(encoding="utf-8")
    try:
        CODEACT.write_text(orig_c.replace("installed_refusing", "skipped"), encoding="utf-8")
        r = run()
        ok = note(rows, "absent-skip-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        CODEACT.write_text(orig_c, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant monty-pin: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
