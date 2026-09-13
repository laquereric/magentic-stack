#!/usr/bin/env python3
"""Fail if SWITCH forgets that catalog prices are INDICATIVE, or the pin vanishes.

docs/pydantic-upgrades.md rec 3. ROLE=config still owns llm_catalog.json.
This gate holds the admission and the pin record; it does not vendor data.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

PIN = Path("upstreams/manifests/genai-prices.pin.json")
CATALOG = Path("runtimes/switch/catalog.mjs")


def fail_empty_check_root():
    if "CHECK_ROOT" in os.environ and not str(os.environ.get("CHECK_ROOT", "")).strip():
        print("FAIL: empty CHECK_ROOT", file=sys.stderr)
        return True
    return False


def root_from_env():
    raw = os.environ.get("CHECK_ROOT")
    if raw is None:
        return Path(__file__).resolve().parents[2]
    return Path(raw)


def main() -> int:
    if fail_empty_check_root():
        return 1
    root = root_from_env()
    checks = []

    def check(name, ok, detail=""):
        checks.append((name, bool(ok), str(detail)))
        return bool(ok)

    pin = json.loads((root / PIN).read_text(encoding="utf-8"))
    cat = (root / CATALOG).read_text(encoding="utf-8")
    ok = True
    ok = check("kind-data", pin.get("kind") == "data", pin.get("kind")) and ok
    ok = check("not-fork", pin.get("fork") is False, pin.get("fork")) and ok
    ok = check("catalog-indicative", "INDICATIVE" in cat, "INDICATIVE") and ok
    ok = check("catalog-cites-pin", "genai-prices" in cat, "genai-prices") and ok
    populated, _pop = emit_population(len(checks))
    if not populated:
        return 1
    print("check | ok | detail")
    print("------|----|--------")
    for name, passed, detail in checks:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    if not ok:
        print("genai-prices-pin: FAIL", file=sys.stderr)
        return 1
    print("genai-prices-pin: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
