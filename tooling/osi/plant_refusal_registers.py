#!/usr/bin/env python3
"""Plants for ADR 0064. Each rule of check_refusal_registers must FAIL when
violated, or it is decoration.

Every plant is a defect this tree actually shipped or came within one commit of
shipping:

  reason-from-conforms  the code as written on 2026-09-04, before ADR 0064
  response-refused-as-request-refusal  the first version of the 4.7 fix, which
      recorded a refused ANSWER as a non-conforming REQUEST
  published-refusal     the change nobody has made yet, and the reason the rule
      exists: an unvalidated payload promoted out of private_local

Edits the real file and restores it. Restores on failure too.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/osi/check_refusal_registers.py"
ADAPTER = ROOT / "gems/rails-osi-level-8/lib/rails_osi_level_8/cpcp_adapter.rb"


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

    orig = ADAPTER.read_text(encoding="utf-8")
    try:
        # 1. the reason restated from the boolean -- the shipped defect
        planted = orig.replace(
            "        refusal_reason: reason,",
            "        refusal_reason: conforms ? nil : reason,",
            1,
        )
        if planted == orig:
            ok = note(rows, "reason-from-conforms-edit", False, "could not plant") and ok
        else:
            ADAPTER.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "reason-from-conforms-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
            ADAPTER.write_text(orig, encoding="utf-8")

        # 2. a refused answer filed as a bad request -- the first fix's mistake
        planted = orig.replace(
            'record_admission!(params, request_cid, outbound, conforms: true, reason: "response_refused")',
            'record_admission!(params, request_cid, outbound, conforms: false, reason: "response_refused")',
            1,
        )
        if planted == orig:
            ok = note(rows, "response-refused-edit", False, "could not plant") and ok
        else:
            ADAPTER.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "response-refused-as-request-refusal-fails",
                      r.returncode != 0, "exit %d" % r.returncode) and ok
            ADAPTER.write_text(orig, encoding="utf-8")

        # 3. refusal evidence promoted out of private_local
        planted = orig.replace(
            '        ledger_placement: "private_local",\n        provenance_json: {},',
            '        ledger_placement: "canonical",\n        provenance_json: {},',
            1,
        )
        if planted == orig:
            ok = note(rows, "published-refusal-edit", False, "could not plant") and ok
        else:
            ADAPTER.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "published-refusal-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
            ADAPTER.write_text(orig, encoding="utf-8")
    finally:
        ADAPTER.write_text(orig, encoding="utf-8")

    r = run()
    ok = note(rows, "restored", r.returncode == 0, "exit %d" % r.returncode) and ok

    for name, passed, detail in rows:
        print("  %-42s %-4s %s" % (name, "ok" if passed else "FAIL", detail))
    print("refusal-registers plants: %s (%d)" % ("OK" if ok else "FAIL", len(rows)))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
