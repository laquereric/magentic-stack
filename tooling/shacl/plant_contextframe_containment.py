#!/usr/bin/env python3
"""Plants for gap 107. Peer-not-contained, p8 reuse, or missing file must fail.
Restores files.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/shacl/check_contextframe_containment.py"
SRC = ROOT / "gems/shapes-level-8/bundles/contextframe.shacl.ttl"


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

    orig = SRC.read_text(encoding="utf-8")
    try:
        # Putting the tree back: maxCount 1 on an activation is exactly the
        # rule MeaningActivations.md amends away.
        planted = orig.replace(
            "sh:path cf:frameActivation ;\n    sh:minCount 1 ;",
            "sh:path cf:frameActivation ;\n    sh:minCount 1 ; sh:maxCount 1 ;",
            1,
        )
        if planted == orig:
            ok = note(rows, "recap-edit", False, "could not add maxCount") and ok
        else:
            SRC.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "activation-capped-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        SRC.write_text(orig, encoding="utf-8")

    orig = SRC.read_text(encoding="utf-8")
    try:
        # Plants the SAME defect against the amended shape: a meaning that
        # names no frame is unanchored, which is what gap 107 was written to
        # prevent and what MeaningActivations.md kept. The predicate moved from
        # cf:inContextFrame to cf:frameActivation; the property being defended
        # did not.
        planted = orig.replace(
            "sh:path cf:frameActivation ;\n    sh:minCount 1 ;",
            "sh:path cf:frameActivation ;\n    sh:minCount 0 ;",
            1,
        )
        if planted == orig:
            ok = note(rows, "peer-edit", False, "could not drop minCount") and ok
        else:
            SRC.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "peer-not-contained-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        SRC.write_text(orig, encoding="utf-8")

    orig = SRC.read_text(encoding="utf-8")
    try:
        planted = orig.replace("cf:ContextFrameShape", "cf:FrameChangeShape", 1)
        planted = planted.replace("cf:ContextFrame ", "p8:FrameChange ", 1)
        SRC.write_text(planted + "\n# frameName frameDigest\n", encoding="utf-8")
        r = run()
        ok = note(rows, "p8-reuse-fails", r.returncode != 0,
                  "exit %d" % r.returncode) and ok
    finally:
        SRC.write_text(orig, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant contextframe-containment: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
