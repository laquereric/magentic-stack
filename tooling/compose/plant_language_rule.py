#!/usr/bin/env python3
"""Plants for gap 12. Empty CHECK_ROOT, dropping the graph exemption,
and dropping the switch violation must fail. Restores files.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/compose/check_language_rule.py"
RULE = ROOT / "tooling/compose/language_rule.json"


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

    orig = RULE.read_text(encoding="utf-8")
    data = json.loads(orig)
    try:
        data["exemptions"] = []
        RULE.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        r = run()
        ok = note(rows, "drop-exemption-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        RULE.write_text(orig, encoding="utf-8")

    data = json.loads(orig)
    try:
        data["violations"] = []
        RULE.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        r = run()
        ok = note(rows, "drop-violation-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        RULE.write_text(orig, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant language-rule: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
