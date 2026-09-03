#!/usr/bin/env python3
"""Fail if KV-cache block-reuse machinery appears without the admission
contract. There is deliberately no such consumer today (GAP11_CACHE.md):
no gate can bind it and no fixture can exercise it, so building one
would be speculative machinery. This tripwire fails closed on arrival
instead -- the failure IS the row-83 reactivation.

Snapshots are NOT in scope: NOOA save/restore is whole-state durability
sanctioned by row 82, not cross-execution block reuse.

Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

MIND = Path("runtimes/mind-pod/mind")
SWITCH = Path("runtimes/switch")
MIND_FILES = ("harness.py", "mind_agent.py", "mind_seam.py", "mind_cells.py")
SWITCH_FILES = ("server.mjs", "sources.mjs", "router.mjs", "discovery.mjs",
                "verify.mjs", "catalog.mjs", "providers.mjs", "translate.mjs",
                "vault.mjs")
UI = Path("runtimes/switch/ui/ui.js")
TOKENS = ("kv_cache", "kvcache", "KVCache", "prefix_cache", "cache_reuse",
          "reuse_cache", "cache_admission", "admit_cached")


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


def main():
    if fail_empty_check_root():
        return 1
    root = root_from_env()
    if not root.is_dir():
        print("FAIL: CHECK_ROOT is not a directory: %s" % root, file=sys.stderr)
        return 1
    try:
        nonempty = any(root.iterdir())
    except OSError as e:
        print("FAIL: CHECK_ROOT unreadable: %s" % e, file=sys.stderr)
        return 1
    if not nonempty:
        print("FAIL: empty CHECK_ROOT tree", file=sys.stderr)
        return 1

    errors = []
    examined = 0

    targets = ([MIND / f for f in MIND_FILES]
               + [SWITCH / f for f in SWITCH_FILES] + [UI])
    for rel in targets:
        examined += 1
        p = root / rel
        text = p.read_text(encoding="utf-8", errors="replace") if p.is_file() else ""
        if not p.is_file():
            errors.append("missing %s" % rel.as_posix())
            continue
        hits = sorted({t for t in TOKENS if t in text})
        if hits:
            errors.append(
                "%s grows block-reuse machinery %s without the row-83 admission contract (GAP11_CACHE.md)"
                % (rel.as_posix(), hits)
            )
        else:
            print("  ok %s has no block-reuse surface" % rel.as_posix())

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("NO KV CACHE FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("no kv cache: OK (dormant, tripwired)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
