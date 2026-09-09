#!/usr/bin/env python3
"""Plants for NATS-exclusive in-pod transport. Empty CHECK_ROOT, dropping
the exclusive sentence, and restoring a fallback phrase must fail.
"""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/compose/check_nats_exclusive.py"
# Imported by copying the checker's list so a drift fails the plant, not
# the live tree.
sys.path.insert(0, str(ROOT / "tooling" / "compose"))
from check_nats_exclusive import CLIENTS  # noqa: E402


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

    with tempfile.TemporaryDirectory(prefix="nats-excl-") as raw:
        d = Path(raw)
        for rel in CLIENTS:
            src = ROOT / rel
            dest = d / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_text(src.read_text(encoding="utf-8"), encoding="utf-8")
        sample = d / "runtimes/switch/vault.mjs"
        sample.write_text(
            sample.read_text(encoding="utf-8").replace(
                "HTTP is not a fallback", "HTTP IS A FALLBACK"
            ),
            encoding="utf-8",
        )
        r = run({"CHECK_ROOT": str(d)})
        ok = note(rows, "drop-sentence-fails", r.returncode != 0, "exit %d" % r.returncode) and ok

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant nats-exclusive: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
