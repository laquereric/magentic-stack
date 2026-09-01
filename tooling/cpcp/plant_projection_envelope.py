#!/usr/bin/env python3
"""Plants for gap 93. Empty CHECK_ROOT and a reason-allowlist
failed_envelope? must fail. Restores files.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/cpcp/check_projection_envelope.py"
STORABLE = ROOT / "gems/vv-graph/lib/vv/graph/storable.rb"
OLD = "env.is_a?(::Hash) && env[:ok] == false"
NEW = "env.is_a?(::Hash) && env[:ok] == false && env[:reason] == :graph_unreachable"


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

    orig = STORABLE.read_text(encoding="utf-8")
    if OLD not in orig:
        ok = note(rows, "plant-edit", False, "could not find failed_envelope? body") and ok
    else:
        try:
            STORABLE.write_text(orig.replace(OLD, NEW, 1), encoding="utf-8")
            r = run()
            ok = note(
                rows,
                "reason-allowlist-fails",
                r.returncode != 0,
                "exit %d" % r.returncode,
            ) and ok
        finally:
            STORABLE.write_text(orig, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant projection-envelope: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
