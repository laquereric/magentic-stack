#!/usr/bin/env python3
"""Plants for row 10 slice 2. Empty CHECK_ROOT, a 4th method, a framework
import, a BACK-dial import, a published mind port. Restores files.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/cpcp/check_mind_seam.py"
SEAM = ROOT / "runtimes/mind-pod/mind/mind_seam.py"
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

    orig = SEAM.read_text(encoding="utf-8")

    def plant_seam(name, old, new):
        nonlocal ok
        planted = orig.replace(old, new, 1)
        if planted == orig:
            ok = note(rows, name + "-edit", False, "could not plant") and ok
            return
        SEAM.write_text(planted, encoding="utf-8")
        try:
            r = run()
            ok = note(rows, name, r.returncode != 0, "exit %d" % r.returncode) and ok
        finally:
            SEAM.write_text(orig, encoding="utf-8")

    plant_seam(
        "extra-method-fails",
        '    "mind.up",\n)',
        '    "mind.up",\n    "mind.evil",\n)',
    )
    plant_seam(
        "framework-import-fails",
        "import threading\n",
        "import threading\nimport flask\n",
    )
    plant_seam(
        "back-dial-fails",
        "import threading\n",
        "import threading\nimport urllib.request\n",
    )

    orig_d = COMPOSE.read_text(encoding="utf-8")
    try:
        planted = orig_d.replace(
            '    expose: [ "8091" ]\n  switch:',
            '    ports: [ "8091:8091" ]\n  switch:',
            1,
        )
        # The mind block ends before "  switch:"; anchor on it.
        if planted == orig_d:
            ok = note(rows, "publish-edit", False, "could not plant") and ok
        else:
            COMPOSE.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "published-port-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        COMPOSE.write_text(orig_d, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant mind-seam: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
