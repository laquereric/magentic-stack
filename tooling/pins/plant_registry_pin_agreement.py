#!/usr/bin/env python3
"""Plants for check_registry_pin_agreement.

Each is the drift the checker exists for: one site moved, one site abbreviated,
one site missing. Edits the real files and restores them, including on failure.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/pins/check_registry_pin_agreement.py"
APP = ROOT / ".cpcp/package.json"
PIN = ROOT / "upstreams/manifests/cpcp_registry.pin.json"


def run(env=None):
    e = os.environ.copy()
    e.pop("CHECK_ROOT", None)
    if env:
        e.update(env)
    return subprocess.run(
        [sys.executable, str(CHECKER)], cwd=str(ROOT), env=e,
        capture_output=True, text=True,
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

    app_orig = APP.read_text(encoding="utf-8")
    pin_orig = PIN.read_text(encoding="utf-8")
    try:
        # 1. one site moved on while the others stayed -- the drift itself
        moved = app_orig.replace(
            "30975bad7f86a86ea5bd3e1ad74c53b7fcd00dac",
            "0000000000000000000000000000000000000000", 1,
        )
        if moved == app_orig:
            ok = note(rows, "drift-edit", False, "could not plant") and ok
        else:
            APP.write_text(moved, encoding="utf-8")
            r = run()
            ok = note(rows, "one-site-drifted-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
            APP.write_text(app_orig, encoding="utf-8")

        # 2. an ABBREVIATION. It matches by eye and is not agreement.
        short = app_orig.replace("30975bad7f86a86ea5bd3e1ad74c53b7fcd00dac", "30975bad", 1)
        if short == app_orig:
            ok = note(rows, "abbrev-edit", False, "could not plant") and ok
        else:
            APP.write_text(short, encoding="utf-8")
            r = run()
            ok = note(rows, "abbreviated-sha-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
            APP.write_text(app_orig, encoding="utf-8")

        # 3. a site that stopped carrying the pin at all
        dropped = pin_orig.replace('"pinned_revision"', '"pinned_revision_was"', 1)
        if dropped == pin_orig:
            ok = note(rows, "missing-key-edit", False, "could not plant") and ok
        else:
            PIN.write_text(dropped, encoding="utf-8")
            r = run()
            ok = note(rows, "missing-key-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
            PIN.write_text(pin_orig, encoding="utf-8")
    finally:
        APP.write_text(app_orig, encoding="utf-8")
        PIN.write_text(pin_orig, encoding="utf-8")

    r = run()
    ok = note(rows, "restored", r.returncode == 0, "exit %d" % r.returncode) and ok

    for name, passed, detail in rows:
        print("  %-26s %-4s %s" % (name, "ok" if passed else "FAIL", detail))
    print("registry-pin-agreement plants: %s (%d)" % ("OK" if ok else "FAIL", len(rows)))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
