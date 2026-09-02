#!/usr/bin/env python3
"""Plants for gap 68 U5. Swallow-to-[] or collapsing discovery into
:no_storable_models must fail. Restores files.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/cpcp/check_graph_replay_discovery.py"
SRC = ROOT / "runtimes/mind-pod/app/app/services/graph_replay.rb"


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

    orig = SRC.read_text(encoding="utf-8")
    try:
        planted = orig.replace(
            """  rescue StandardError => e
    { ok: false, reason: :storable_discovery_failed,
      because: \"#{e.class}: #{e.message}\" }""",
            "  rescue StandardError\n    []",
        )
        if planted == orig:
            ok = note(rows, "swallow-edit", False, "could not plant rescue []") and ok
        else:
            SRC.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "swallow-to-[]-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        SRC.write_text(orig, encoding="utf-8")

    orig = SRC.read_text(encoding="utf-8")
    try:
        planted = orig.replace(
            """    discovered = storable_models
    return { ok: false, reason: discovered[:reason],
             because: discovered[:because] } unless discovered[:ok]

    models = discovered[:models]""",
            """    discovered = storable_models
    models = discovered.is_a?(Hash) ? (discovered[:models] || []) : discovered""",
        )
        if planted == orig:
            ok = note(rows, "collapse-edit", False, "could not plant collapse") and ok
        else:
            SRC.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "collapse-to-empty-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        SRC.write_text(orig, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant graph-replay-discovery: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
