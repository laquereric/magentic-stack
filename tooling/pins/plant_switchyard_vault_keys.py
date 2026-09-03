#!/usr/bin/env python3
"""Plants for row 11 slice A. Empty CHECK_ROOT, file-key read, UI key
form, missing vault wiring. Restores files.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/pins/check_switchyard_vault_keys.py"
SERVER = ROOT / "runtimes/switch/server.mjs"
UI = ROOT / "runtimes/switch/ui/ui.js"
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
        SERVER,
        "file-key-read-fails",
        "  const key = await vaultKey(vendorId);",
        "  const key = state.keys[vendorId];",
    )
    plant_file(
        UI,
        "ui-key-form-fails",
        "    note.textContent = v.ready ? 'key held in vault' : 'no key — add one in the config UI (vault)';",
        "    note.textContent = 'Save key';",
    )
    plant_file(
        COMPOSE,
        "missing-vault-env-fails",
        '      SWITCH_VAULT_TOKEN: "${SWITCH_VAULT_TOKEN:-}"\n',
        "",
    )

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant switchyard-vault-keys: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
