#!/usr/bin/env python3
"""Plants for gap 96. Empty CHECK_ROOT, a renamed target, and a doc
in enforced_by must fail. Restores files.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/cpcp/check_enforced_by.py"
TARGET = ROOT / "tooling/boundary/check_boundary.py"
ADR0001 = ROOT / "docs/adr/0001-ownership-boundary.md"
ADR0057 = ROOT / "docs/adr/0057-three-kinds-of-state.md"
ADR0048 = ROOT / "docs/adr/0048-mind-serves-a-cpcp-seam.md"


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

    orig = TARGET.read_text(encoding="utf-8") if TARGET.is_file() else None
    renamed = TARGET.with_name("check_boundary.py.renamed")
    try:
        if orig is None:
            ok = note(rows, "rename-edit", False, "missing check_boundary.py") and ok
        else:
            TARGET.rename(renamed)
            r = run()
            ok = note(rows, "rename-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        if renamed.is_file() and not TARGET.is_file():
            renamed.rename(TARGET)

    adr_orig = ADR0001.read_text(encoding="utf-8")
    try:
        planted = adr_orig.replace(
            "  - tooling/boundary/check_boundary.py\n",
            "  - docs/architecture/COVERAGE_GAPS.md\n",
            1,
        )
        if planted == adr_orig:
            ok = note(rows, "neither-edit", False, "could not plant a doc as enforced_by") and ok
        else:
            ADR0001.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "neither-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        ADR0001.write_text(adr_orig, encoding="utf-8")

    adr57 = ADR0057.read_text(encoding="utf-8")
    try:
        planted = adr57.replace(
            "enforced_by:\n  - tooling/compose/check_two_writers.py\n",
            "enforced_by: []\n",
            1,
        )
        if planted == adr57:
            ok = note(rows, "97-empty-ebs-edit", False, "could not empty 0057 enforced_by") and ok
        else:
            ADR0057.write_text(planted, encoding="utf-8")
            r = run()
            hit = "names check_two_writers.py but enforced_by does not" in (r.stderr or "")
            ok = note(
                rows, "97-because-names-checker-empty-ebs-fails",
                r.returncode != 0 and hit,
                "exit %d hit=%s" % (r.returncode, hit),
            ) and ok
    finally:
        ADR0057.write_text(adr57, encoding="utf-8")

    adr48 = ADR0048.read_text(encoding="utf-8")
    try:
        planted = adr48.replace(
            'unenforced_because: "MIND /_cpcp seam is accepted and unbuilt (row 10); stand-in is the current client-only boundary test"',
            'unenforced_because: "MIND /_cpcp seam is accepted and unbuilt (row 10); writers are gated by check_two_writers.py"',
            1,
        )
        if planted == adr48:
            ok = note(rows, "97-0048-edit", False, "could not plant gated-by on 0048") and ok
        else:
            ADR0048.write_text(planted, encoding="utf-8")
            r = run()
            hit = "names check_two_writers.py but enforced_by does not" in (r.stderr or "")
            ok = note(
                rows, "97-whole-because-names-checker-fails",
                r.returncode != 0 and hit,
                "exit %d hit=%s" % (r.returncode, hit),
            ) and ok
    finally:
        ADR0048.write_text(adr48, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant enforced_by: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
