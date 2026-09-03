#!/usr/bin/env python3
"""Plants for ADR 0061. Empty CHECK_ROOT, pin.json SHA move without
reviews[], quote stripped from the ADR. Restores files. Does not
checkout a different submodule commit.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/pins/check_switchyard_pin.py"
PIN = ROOT / "upstreams/manifests/nemo-switchyard.pin.json"
ADR = ROOT / "docs/adr/0061-switchyard-pre-alpha-pin-is-the-accepted-risk.md"
FAKE = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"


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

    orig_p = PIN.read_text(encoding="utf-8")
    try:
        data = json.loads(orig_p)
        data["pinned_revision"] = FAKE
        PIN.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        r = run()
        ok = note(rows, "pin-move-without-review-fails", r.returncode != 0,
                  "exit %d" % r.returncode) and ok
    finally:
        PIN.write_text(orig_p, encoding="utf-8")

    try:
        data = json.loads(orig_p)
        data["pinned_revision"] = FAKE
        data["reviews"] = [{
            "sha": FAKE,
            "from_sha": data.get("pinned_revision"),
            "at": "2026-09-03",
            "by": "plant",
            "looked_at": "",
            "because": "",
        }]
        # restore from_sha to original after we overwrote pinned_revision
        data["reviews"][0]["from_sha"] = json.loads(orig_p)["pinned_revision"]
        PIN.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        r = run()
        ok = note(rows, "empty-looked-at-fails", r.returncode != 0,
                  "exit %d" % r.returncode) and ok
    finally:
        PIN.write_text(orig_p, encoding="utf-8")

    try:
        data = json.loads(orig_p)
        data["submodule_path"] = ""
        PIN.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        r = run()
        ok = note(rows, "empty-submodule-path-fails", r.returncode != 0,
                  "exit %d" % r.returncode) and ok
    finally:
        PIN.write_text(orig_p, encoding="utf-8")

    orig_a = ADR.read_text(encoding="utf-8")
    try:
        planted = orig_a.replace(
            "Experimental software. Not for production use.",
            "maybe fine in production",
            1,
        )
        if planted == orig_a:
            ok = note(rows, "quote-edit", False, "could not plant") and ok
        else:
            ADR.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "quote-stripped-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        ADR.write_text(orig_a, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant switchyard-pin: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
