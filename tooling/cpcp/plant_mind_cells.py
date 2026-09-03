#!/usr/bin/env python3
"""Plants for row-10 cells. Empty CHECK_ROOT, unwired harness, unshipped
module, framework import. Restores files.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/cpcp/check_mind_cells.py"
HARNESS = ROOT / "runtimes/mind-pod/mind/harness.py"
CELLS = ROOT / "runtimes/mind-pod/mind/mind_cells.py"
DOCKERFILE = ROOT / "runtimes/mind-pod/mind/Dockerfile"


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

    def plant_file(path, name, old, new):
        nonlocal ok
        orig = path.read_text(encoding="utf-8")
        planted = orig.replace(old, new, 1)
        if planted == orig:
            ok = note(rows, name + "-edit", False, "could not plant") and ok
            return
        path.write_text(planted, encoding="utf-8")
        try:
            r = run()
            ok = note(rows, name, r.returncode != 0, "exit %d" % r.returncode) and ok
        finally:
            path.write_text(orig, encoding="utf-8")

    plant_file(
        HARNESS,
        "unwired-harness-fails",
        "    cells = mind_cells.from_agent(agent, skip=seen)\n",
        "    cells = []\n",
    )
    plant_file(
        DOCKERFILE,
        "unshipped-module-fails",
        "COPY harness.py mind_agent.py mind_seam.py mind_cells.py ./",
        "COPY harness.py mind_agent.py mind_seam.py ./",
    )
    plant_file(
        CELLS,
        "framework-import-fails",
        "import hashlib\n",
        "import hashlib\nimport requests\n",
    )

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant mind-cells: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
