#!/usr/bin/env python3
"""Plants for the row-83 tripwire. Empty CHECK_ROOT, block-reuse tokens
in mind and switch code. Restores files.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/pins/check_no_kv_cache.py"
HARNESS = ROOT / "runtimes/mind-pod/mind/harness.py"
SERVER = ROOT / "runtimes/switch/server.mjs"


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

    def plant_file(path, name, anchor):
        nonlocal ok
        orig = path.read_text(encoding="utf-8")
        planted = orig + anchor
        path.write_text(planted, encoding="utf-8")
        try:
            r = run()
            ok = note(rows, name, r.returncode != 0, "exit %d" % r.returncode) and ok
        finally:
            path.write_text(orig, encoding="utf-8")

    plant_file(HARNESS, "mind-reuse-fails", "\n# planted\nkv_cache = {}\n")
    plant_file(SERVER, "switch-reuse-fails", "\n// planted\nconst prefix_cache = {};\n")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant no-kv-cache: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
