#!/usr/bin/env python3
"""Plants for gap 20. Undeclared live server, empty authority, empty CHECK_ROOT.
Restores files.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/cpcp/check_seam_authority.py"
TABLE = ROOT / "tooling/cpcp/seam_authority.json"
CALLERS = ROOT / "tooling/cpcp/cpcp_callers.json"


def run(env=None):
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


def main():
    rows = []
    ok = True
    env = os.environ.copy()
    env.pop("CHECK_ROOT", None)

    r = run(env)
    rows.append(("clean", r.returncode == 0, "exit %d" % r.returncode))
    ok = ok and r.returncode == 0

    r = run({**env, "CHECK_ROOT": ""})
    rows.append(("empty-root", r.returncode != 0, "exit %d" % r.returncode))
    ok = ok and r.returncode != 0

    orig_t = TABLE.read_text(encoding="utf-8")
    try:
        data = json.loads(orig_t)
        data["live"][0]["authoritative_for"] = ""
        TABLE.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        r = run(env)
        hit = "empty authoritative_for" in (r.stderr or "")
        rows.append(("empty-authority-fails", r.returncode != 0 and hit,
                     "exit %d hit=%s" % (r.returncode, hit)))
        ok = ok and r.returncode != 0 and hit
    finally:
        TABLE.write_text(orig_t, encoding="utf-8")

    orig_c = CALLERS.read_text(encoding="utf-8")
    try:
        data = json.loads(orig_c)
        data["entries"].append({
            "file": "runtimes/mind-pod/mind/harness.py",
            "lang": "python",
            "kind": "server",
            "role": "plant",
            "because": "plant a server that is actually a caller",
        })
        CALLERS.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        r = run(env)
        hit = "new seam without authority" in (r.stderr or "") or "not on a live seam" in (r.stderr or "")
        rows.append(("undeclared-server-fails", r.returncode != 0 and hit,
                     "exit %d hit=%s" % (r.returncode, hit)))
        ok = ok and r.returncode != 0 and hit
    finally:
        CALLERS.write_text(orig_c, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant seam-authority: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
