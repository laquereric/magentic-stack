#!/usr/bin/env python3
"""Plants for gap 94. Missing or diverged app outbox migration must fail.
Restores files.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/cpcp/check_outbox_migrated.py"
APP = ROOT / "runtimes/mind-pod/app/db/migrate/20260811170000_create_vv_graph_projection_jobs.rb"


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

    orig = APP.read_text(encoding="utf-8") if APP.is_file() else None
    try:
        if orig is None:
            ok = note(rows, "delete-app-copy", False, "app migration missing before plant") and ok
        else:
            APP.unlink()
            r = run()
            ok = note(rows, "delete-app-copy-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
            APP.write_text(orig + "\n# planted divergence\n", encoding="utf-8")
            r = run()
            ok = note(rows, "diverge-app-copy-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        if orig is not None:
            APP.write_text(orig, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant outbox-migrated: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
