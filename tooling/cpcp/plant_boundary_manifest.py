#!/usr/bin/env python3
"""Plants for row 106. Empty CHECK_ROOT, unmanifested method, ghost entry.
Restores files.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/cpcp/check_boundary_manifest.py"
BUS = ROOT / "runtimes/mind-pod/app/app/controllers/bus_cpcp_controller.rb"
MANIFEST = ROOT / "tooling/cpcp/boundary_manifest.json"


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

    orig_b = BUS.read_text(encoding="utf-8")
    try:
        planted = orig_b.replace(
            '"bus.projection.latest" => :latest',
            '"bus.projection.latest" => :latest,\n    "bus.projection.ghost" => :latest',
            1,
        )
        if planted == orig_b:
            ok = note(rows, "method-edit", False, "could not plant") and ok
        else:
            BUS.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "unmanifested-method-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        BUS.write_text(orig_b, encoding="utf-8")

    orig_m = MANIFEST.read_text(encoding="utf-8")
    try:
        data = json.loads(orig_m)
        data["methods"].append({
            "operation_iri": "https://w3id.org/cpcp/osi8/bus#ghost",
            "wire_method": "bus.projection.ghost",
            "seam": "bus",
            "producer": "bus",
            "consumers": ["nobody"],
            "params": "{}",
            "result": "nothing",
            "refusals": [],
            "profiles": [],
        })
        MANIFEST.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        r = run()
        ok = note(rows, "ghost-entry-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        MANIFEST.write_text(orig_m, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant boundary-manifest: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
