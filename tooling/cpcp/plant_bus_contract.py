#!/usr/bin/env python3
"""Plants for row 75. Empty CHECK_ROOT, dropped version, unserved version.
Restores files.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/cpcp/check_bus_contract.py"
PROJECTOR = ROOT / "runtimes/mind-pod/app/app/services/bus/projector.rb"


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

    orig = PROJECTOR.read_text(encoding="utf-8")

    def plant_file(name, old, new):
        nonlocal ok
        planted = orig.replace(old, new, 1)
        if planted == orig:
            ok = note(rows, name + "-edit", False, "could not plant") and ok
            return
        PROJECTOR.write_text(planted, encoding="utf-8")
        try:
            r = run()
            ok = note(rows, name, r.returncode != 0, "exit %d" % r.returncode) and ok
        finally:
            PROJECTOR.write_text(orig, encoding="utf-8")

    plant_file("dropped-version-fails", "    CONTRACT_VERSION = 1\n", "")
    plant_file("unserved-version-fails", '        "contract_version" => CONTRACT_VERSION,\n', "")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant bus-contract: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
