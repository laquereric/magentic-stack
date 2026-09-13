#!/usr/bin/env python3
"""Fail if SWITCH forgets INDICATIVE prices, or the overlay digest drifts.

docs/pydantic-upgrades.md rec 3. ROLE=config still owns llm_catalog.json.
The overlay snapshot is gems/adapters/genai-prices/data_slim.json.
catalog.mjs must not load that file. Empty CHECK_ROOT fails.
"""
from __future__ import annotations

import hashlib
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

PIN = Path("upstreams/manifests/genai-prices.pin.json")
CATALOG = Path("runtimes/switch/catalog.mjs")
JSON_REL = Path("runtimes/mind-pod/app/config/llm_catalog.json")
OVERLAY = Path("gems/adapters/genai-prices/overlay.py")
DATA = Path("gems/adapters/genai-prices/data_slim.json")
WANT_VER = "0.1.6"


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

    pin = json.loads((root / PIN).read_text(encoding="utf-8")) if (root / PIN).is_file() else {}
    cat = (root / CATALOG).read_text(encoding="utf-8") if (root / CATALOG).is_file() else ""
    table = (root / JSON_REL).read_text(encoding="utf-8") if (root / JSON_REL).is_file() else ""
    overlay = (root / OVERLAY).read_text(encoding="utf-8") if (root / OVERLAY).is_file() else ""
    data_path = root / DATA
    ok = True
    ok = check("kind-data", pin.get("kind") == "data", pin.get("kind")) and ok
    ok = check("not-fork", pin.get("fork") is False, pin.get("fork")) and ok
    ver = str(pin.get("pinned_version") or "")
    rb = str(pin.get("rollback_target") or "")
    ok = check("version-set", ver == WANT_VER, ver) and ok
    ok = check("rollback-set", bool(rb) and rb != "PENDING" and rb != ver, rb) and ok
    ok = check("catalog-indicative", "INDICATIVE" in cat, "INDICATIVE") and ok
    ok = check("catalog-cites-pin", "genai-prices" in cat, "genai-prices") and ok
    ok = check("no-second-table", "data_slim.json" not in cat, "catalog.mjs must not load the overlay file") and ok
    ok = check("table-indicative", "INDICATIVE" in table, "llm_catalog.json INDICATIVE") and ok
    ok = check("overlay-present", bool(overlay), str(OVERLAY)) and ok
    if overlay:
        ok = check("overlay-skips-openrouter", "openrouter" in overlay, "SKIP openrouter") and ok
    digest = str(pin.get("data_sha256") or "")
    ok = check("digest-set", len(digest) == 64, digest[:16]) and ok
    ok = check("data-file", data_path.is_file(), str(DATA)) and ok
    if data_path.is_file() and len(digest) == 64:
        live = hashlib.sha256(data_path.read_bytes()).hexdigest()
        ok = check("digest-matches", live == digest, live) and ok
    rel = str(pin.get("data_file") or "")
    ok = check("data-file-in-adapter", rel == DATA.as_posix(), rel) and ok

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
