#!/usr/bin/env python3
"""Plants for gaps 66 and 67. Restore files even on failure.

66: point L8_PROTOCOL_MAP at APP; catalog-manifest must FAIL.
67: change a packaged minCount; packaged-legacy must FAIL (real byte
    drift). Then restore. Does not strip comments.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "gems/rails-osi-level-8/lib/rails_osi_level_8/profile_catalog.rb"
L8_P11 = ROOT / "gems/shapes-level-8/bundles/profile-11-meaning.ttl"
CHECK_CM = ROOT / "tooling/shacl/check_catalog_manifest.py"
CHECK_PL = ROOT / "tooling/shacl/check_packaged_legacy.py"


def run(script: Path) -> int:
    return subprocess.run(
        [sys.executable, str(script)],
        cwd=str(ROOT),
        capture_output=True,
        text=True,
    ).returncode


def main():
    rows = []
    ok = True

    rc = run(CHECK_CM)
    rows.append(("66-clean", rc == 0, "check_catalog_manifest exit %d" % rc))
    ok = ok and rc == 0

    orig_cat = CATALOG.read_text(encoding="utf-8")
    try:
        planted = orig_cat.replace("[L8,", "[APP,")
        if planted == orig_cat:
            rows.append(("66-plant-edit", False, "no [L8, to replace"))
            ok = False
        else:
            CATALOG.write_text(planted)
            rc = run(CHECK_CM)
            rows.append(("66-diverge-fails", rc != 0, "after L8->APP exit %d (want non-zero)" % rc))
            ok = ok and rc != 0
    finally:
        CATALOG.write_text(orig_cat)

    rc = run(CHECK_PL)
    rows.append(("67-clean", rc == 0, "check_packaged_legacy exit %d" % rc))
    ok = ok and rc == 0

    orig_ttl = L8_P11.read_text(encoding="utf-8")
    try:
        planted = orig_ttl.replace("sh:minCount 1 ; sh:maxCount 1 ; sh:nodeKind sh:IRI",
                                   "sh:minCount 2 ; sh:maxCount 1 ; sh:nodeKind sh:IRI", 1)
        if planted == orig_ttl:
            planted = orig_ttl.replace("sh:minCount 1", "sh:minCount 2", 1)
        if planted == orig_ttl:
            rows.append(("67-plant-edit", False, "could not plant a minCount change"))
            ok = False
        else:
            L8_P11.write_text(planted)
            rc = run(CHECK_PL)
            rows.append(("67-semantic-drift-fails", rc != 0,
                         "after minCount 1->2 exit %d (want non-zero)" % rc))
            ok = ok and rc != 0
    finally:
        L8_P11.write_text(orig_ttl)

    print("PLANT TABLE")
    for name, passed, detail in rows:
        print("  %s  %s: %s" % ("OK " if passed else "FAIL", name, detail))
    print("plant catalogue: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
