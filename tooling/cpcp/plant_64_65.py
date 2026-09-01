#!/usr/bin/env python3
"""Plants for gaps 64 and 65. Restores files. Empty CHECK_ROOT and a
source revert must fail the new checkers.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FM = ROOT / "tooling/cpcp/check_frontmatter_parse.py"
ID = ROOT / "tooling/cpcp/check_idempotency_visible.py"
DOC = ROOT / "gems/mmg-adr/lib/mmg/adr/document.rb"
IDEM = ROOT / "gems/rails-cpcp/lib/rails_cpcp/idempotency.rb"


def run(script: Path, env=None) -> subprocess.CompletedProcess:
    e = os.environ.copy()
    if env:
        e.update(env)
    return subprocess.run([sys.executable, str(script)], cwd=str(ROOT), env=e,
                          capture_output=True, text=True)


def main():
    rows = []
    ok = True

    r = run(FM)
    rows.append(("64-clean", r.returncode == 0, "exit %d" % r.returncode))
    ok = ok and r.returncode == 0
    r = run(FM, {"CHECK_ROOT": ""})
    rows.append(("64-empty-root", r.returncode != 0, "exit %d" % r.returncode))
    ok = ok and r.returncode != 0

    orig = DOC.read_text(encoding="utf-8")
    try:
        planted = orig.replace(
            "because: { \"detail\" => \"YAML did not parse\", \"class\" => e.class.name }",
            "{}",
        )
        # cruder plant: restore swallow
        planted = orig.replace(
            """        rescue StandardError => e
          return {
            ok: false,
            reason: :unparsable_frontmatter,
            because: { "detail" => "YAML did not parse", "class" => e.class.name }
          }""",
            "        rescue StandardError\n          {}",
        )
        if planted == orig:
            rows.append(("64-plant-edit", False, "could not plant swallow"))
            ok = False
        else:
            DOC.write_text(planted)
            r = run(FM)
            rows.append(("64-swallow-fails", r.returncode != 0, "exit %d" % r.returncode))
            ok = ok and r.returncode != 0
    finally:
        DOC.write_text(orig)

    r = run(ID)
    rows.append(("65-clean", r.returncode == 0, "exit %d" % r.returncode))
    ok = ok and r.returncode == 0
    r = run(ID, {"CHECK_ROOT": ""})
    rows.append(("65-empty-root", r.returncode != 0, "exit %d" % r.returncode))
    ok = ok and r.returncode != 0

    orig_i = IDEM.read_text(encoding="utf-8")
    try:
        planted = orig_i.replace('reason: "idempotency_not_durable"', 'reason: "gone"')
        if planted == orig_i:
            rows.append(("65-plant-edit", False, "could not plant"))
            ok = False
        else:
            IDEM.write_text(planted)
            r = run(ID)
            rows.append(("65-hidden-fails", r.returncode != 0, "exit %d" % r.returncode))
            ok = ok and r.returncode != 0
    finally:
        IDEM.write_text(orig_i)

    print("PLANT TABLE")
    for name, passed, detail in rows:
        print("  %s  %s: %s" % ("OK " if passed else "FAIL", name, detail))
    print("plant 64-65: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
