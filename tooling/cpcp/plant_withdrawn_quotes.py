#!/usr/bin/env python3
"""Plants for row 115. Empty CHECK_ROOT, unstriking an origin quote,
an unmatched quote in the Withdrawn list. Restores files.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/cpcp/check_withdrawn_quotes.py"
ADR = ROOT / "docs/adr/0050-switchyard-is-the-upstream-plus-bus-and-persist-roles.md"


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
    ok = note(rows, "clean", r.returncode == 0, "exit %d stderr=%s" % (
        r.returncode, (r.stderr or "").strip().splitlines()[-1] if r.returncode else "none")) and ok
    r = run({"CHECK_ROOT": ""})
    ok = note(rows, "empty-root", r.returncode != 0, "exit %d" % r.returncode) and ok

    orig = ADR.read_text(encoding="utf-8")
    try:
        planted = orig.replace(
            "~~Rails Event Store, with a CPCP\n   interface.~~ *(withdrawn, [amendment 2](#amendment-2-bus-is-the-seam-plus-a-projection-not-an-event-store-2026-09-03))*",
            "Rails Event Store, with a CPCP\n   interface.",
            1,
        )
        if planted == orig:
            ok = note(rows, "unstrike-edit", False, "could not plant") and ok
        else:
            ADR.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "unstrike-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        ADR.write_text(orig, encoding="utf-8")

    try:
        marker = "**Withdrawn, explicitly:**"
        if marker not in orig:
            ok = note(rows, "unmatched-edit", False, "no withdrawn list") and ok
        else:
            planted = orig.replace(
                marker,
                marker + '\n- "this quoted sentence does not exist in the origin at all."',
                1,
            )
            ADR.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "unmatched-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        ADR.write_text(orig, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant withdrawn-quotes: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
