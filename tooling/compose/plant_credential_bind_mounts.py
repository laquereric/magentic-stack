#!/usr/bin/env python3
"""Plants for gap 46. Named-volume conversion, sqlite store, 0046:85 dropped.
Restores files. Does not touch .agent/*.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/compose/check_credential_bind_mounts.py"
COMPOSE = ROOT / "runtimes/mind-pod/docker-compose.yml"
STORE = ROOT / "runtimes/mind-pod/app/app/services/vault/store.rb"
ADR = ROOT / "docs/adr/0046-vault-is-not-the-config-ui.md"


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
    try:
        planted = orig.replace("../../.agent/vault:/vault", "vault-data:/vault", 1)
        if planted == orig:
            ok = note(rows, "named-vol-edit", False, "could not plant") and ok
        else:
            COMPOSE.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "named-volume-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        COMPOSE.write_text(orig, encoding="utf-8")

    orig_s = STORE.read_text(encoding="utf-8")
    try:
        planted = orig_s.replace("JSON.parse", "SQLite3.parse", 1).replace(
            "JSON.generate", "SQLite3.generate", 1
        )
        if planted == orig_s:
            ok = note(rows, "sqlite-edit", False, "could not plant") and ok
        else:
            STORE.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "sqlite-store-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        STORE.write_text(orig_s, encoding="utf-8")

    orig_a = ADR.read_text(encoding="utf-8")
    try:
        planted = orig_a.replace(
            "a named volume is not acceptable",
            "a named volume is now acceptable",
            1,
        )
        if planted == orig_a:
            ok = note(rows, "adr-edit", False, "could not plant") and ok
        else:
            ADR.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "0046-named-ok-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        ADR.write_text(orig_a, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant credential-bind-mounts: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
