#!/usr/bin/env python3
"""Plants for gap 50. Read-back, 200-on-refusal, osi.example, TBD, seam class.
Restores files.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/cpcp/check_vault_cpcp.py"
CONTRACT = ROOT / "tooling/cpcp/vault_cpcp.json"
SEAMS = ROOT / "tooling/cpcp/seam_authority.json"
ADR = ROOT / "docs/adr/0046-vault-is-not-the-config-ui.md"


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

    orig_c = CONTRACT.read_text(encoding="utf-8")
    try:
        data = json.loads(orig_c)
        data["allowlist"]["callers"]["config-admin"].append("vault.secret.get")
        CONTRACT.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        r = run()
        ok = note(rows, "admin-get-fails", r.returncode != 0,
                  "exit %d" % r.returncode) and ok
    finally:
        CONTRACT.write_text(orig_c, encoding="utf-8")

    orig_c = CONTRACT.read_text(encoding="utf-8")
    try:
        data = json.loads(orig_c)
        data["refusal_http_status"]["vault_not_allowlisted"] = 200
        data["never_raise_and_non_200"] = False
        CONTRACT.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        r = run()
        ok = note(rows, "200-on-refusal-fails", r.returncode != 0,
                  "exit %d" % r.returncode) and ok
    finally:
        CONTRACT.write_text(orig_c, encoding="utf-8")

    orig_c = CONTRACT.read_text(encoding="utf-8")
    try:
        data = json.loads(orig_c)
        data["shapes"]["vault.secret.get"] = "https://osi.example/vault#SecretGetRequest"
        CONTRACT.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        r = run()
        ok = note(rows, "osi.example-fails", r.returncode != 0,
                  "exit %d" % r.returncode) and ok
    finally:
        CONTRACT.write_text(orig_c, encoding="utf-8")

    orig_a = ADR.read_text(encoding="utf-8")
    try:
        planted = orig_a.replace(
            "The shape is decided here.",
            "The shape of that contract is not yet decided.",
            1,
        )
        if planted == orig_a:
            ok = note(rows, "tbd-edit", False, "could not plant TBD") and ok
        else:
            ADR.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "tbd-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        ADR.write_text(orig_a, encoding="utf-8")

    orig_s = SEAMS.read_text(encoding="utf-8")
    try:
        data = json.loads(orig_s)
        vault = next(r for r in data["decided_unbuilt"] if r["id"] == "vault")
        data["decided_unbuilt"] = [r for r in data["decided_unbuilt"] if r["id"] != "vault"]
        data["not_a_seam"].append({
            "id": "vault",
            "because": "bespoke REST; CPCP inbound is 0046 amendment 2 unbuilt.",
        })
        SEAMS.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        r = run()
        ok = note(rows, "not-a-seam-fails", r.returncode != 0,
                  "exit %d" % r.returncode) and ok
        _ = vault
    finally:
        SEAMS.write_text(orig_s, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant vault-cpcp: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
