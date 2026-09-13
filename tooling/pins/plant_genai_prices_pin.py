#!/usr/bin/env python3
"""Plant: dropping INDICATIVE, the overlay digest, or the pin version must fail."""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/pins/check_genai_prices_pin.py"
CATALOG = ROOT / "runtimes/switch/catalog.mjs"
PIN = ROOT / "upstreams/manifests/genai-prices.pin.json"


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


def main() -> int:
    rows = []
    ok = True
    r = run()
    ok = note(rows, "clean", r.returncode == 0, "exit %d" % r.returncode) and ok
    r = run({"CHECK_ROOT": ""})
    ok = note(rows, "empty-root", r.returncode != 0, "exit %d" % r.returncode) and ok

    orig = CATALOG.read_text(encoding="utf-8")
    try:
        CATALOG.write_text(orig.replace("INDICATIVE", "authoritative"), encoding="utf-8")
        r = run()
        ok = note(rows, "indicative-stripped-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        CATALOG.write_text(orig, encoding="utf-8")

    orig_p = PIN.read_text(encoding="utf-8")
    try:
        data = json.loads(orig_p)
        data["pinned_version"] = "PENDING"
        PIN.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        r = run()
        ok = note(rows, "version-pending-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
        data = json.loads(orig_p)
        data["data_sha256"] = "0" * 64
        PIN.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        r = run()
        ok = note(rows, "digest-mismatch-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        PIN.write_text(orig_p, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant genai-prices: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
