#!/usr/bin/env python3
"""Plant: dropping INDICATIVE or the pin kind must fail."""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/pins/check_genai_prices_pin.py"
CATALOG = ROOT / "runtimes/switch/catalog.mjs"


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


def main() -> int:
    rows = []
    ok = True
    r = run()
    ok = (r.returncode == 0) and ok
    rows.append(("clean", r.returncode == 0, "exit %d" % r.returncode))
    orig = CATALOG.read_text(encoding="utf-8")
    try:
        CATALOG.write_text(orig.replace("INDICATIVE", "authoritative"), encoding="utf-8")
        r = run()
        ok = (r.returncode != 0) and ok
        rows.append(("indicative-stripped-fails", r.returncode != 0, "exit %d" % r.returncode))
    finally:
        CATALOG.write_text(orig, encoding="utf-8")
    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant genai-prices: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
