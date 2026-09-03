#!/usr/bin/env python3
"""Plants for rows 39/43. Empty CHECK_ROOT, rogue sqlite path, undeclared
bind (back on bus-data), dropped bus volume. Restores files.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/compose/check_store_bindings.py"
COMPOSE = ROOT / "runtimes/mind-pod/docker-compose.yml"


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

    orig = COMPOSE.read_text(encoding="utf-8")

    def plant(name, old, new):
        nonlocal ok
        planted = orig.replace(old, new, 1)
        if planted == orig:
            ok = note(rows, name + "-edit", False, "could not plant") and ok
            return
        COMPOSE.write_text(planted, encoding="utf-8")
        try:
            r = run()
            ok = note(rows, name, r.returncode != 0, "exit %d" % r.returncode) and ok
        finally:
            COMPOSE.write_text(orig, encoding="utf-8")

    plant(
        "rogue-path-fails",
        "BUS_DB_PATH: /bus-data/bus.sqlite3 }",
        "BUS_DB_PATH: /tmp/evil.sqlite3 }",
    )
    plant(
        "back-binds-bus-fails",
        'volumes: [ "mind-data:/data" ]',
        'volumes: [ "mind-data:/data", "bus-data:/bus-data" ]',
    )
    plant(
        "missing-bus-volume-fails",
        'volumes: [ "bus-data:/bus-data", "mind-data:/data:ro" ]',
        'volumes: [ "mind-data:/data:ro" ]',
    )

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant store-bindings: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
