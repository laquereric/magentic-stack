#!/usr/bin/env python3
"""Plants for gap 5. get-in-ALLOWED or urlopen must fail. Restores files.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/cpcp/check_config_vault_client.py"
CLIENT = ROOT / "runtimes/mind-pod/app/app/services/config_admin/vault_client.rb"


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

    orig = CLIENT.read_text(encoding="utf-8")
    try:
        planted = orig.replace(
            '"vault.secret.list" => { verb: :get, path: "/secrets" },',
            '"vault.secret.list" => { verb: :get, path: "/secrets" },\n'
            '      "vault.secret.get" => { verb: :get, path: "/secrets/:name" },',
            1,
        )
        if planted == orig:
            ok = note(rows, "get-edit", False, "could not plant get") and ok
        else:
            CLIENT.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "admin-get-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        CLIENT.write_text(orig, encoding="utf-8")

    orig = CLIENT.read_text(encoding="utf-8")
    try:
        planted = orig.replace("h.request(req)", "urlopen(req)")
        if planted == orig:
            ok = note(rows, "urlopen-edit", False, "could not plant urlopen") and ok
        else:
            CLIENT.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "urlopen-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        CLIENT.write_text(orig, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant config-vault-client: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
