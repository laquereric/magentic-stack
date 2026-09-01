#!/usr/bin/env python3
"""Fail if the live idempotency store still looks durable while it is not.

Gap 65. Default is MemoryIdempotency. SqliteIdempotency is not mounted.
Absence of durable replay must be observed (idempotency_not_durable).
get must stay nil-on-failure. Do not require a sqlite mount.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

SRC = Path("gems/rails-cpcp/lib/rails_cpcp/idempotency.rb")
DISPATCHER = Path("gems/rails-cpcp/lib/rails_cpcp/dispatcher.rb")
MIND = Path("runtimes/mind-pod")


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
    path = root / SRC
    examined += 1
    if not path.is_file():
        errors.append("missing %s" % SRC.as_posix())
        text = ""
    else:
        text = path.read_text(encoding="utf-8", errors="replace")
        print("  ok %s" % SRC.as_posix())

    examined += 1
    if "idempotency_store ||= MemoryIdempotency.new" not in text:
        errors.append("default store is no longer MemoryIdempotency")
    else:
        print("  ok default is MemoryIdempotency")

    examined += 1
    if "SqliteIdempotency" in text and "idempotency_store ||= SqliteIdempotency" in text:
        errors.append("SqliteIdempotency mounted as default — placement is PERSIST")
    else:
        print("  ok SqliteIdempotency is not the default")

    examined += 1
    if 'reason: "idempotency_not_durable"' not in text:
        errors.append("idempotency_not_durable is not recorded")
    else:
        print("  ok idempotency_not_durable recorded")

    examined += 1
    if re.search(r"def durable\?\s*;\s*false", text):
        print("  ok MemoryIdempotency.durable? is false")
    else:
        errors.append("MemoryIdempotency does not declare durable? false")

    examined += 1
    if "return nil unless @db" not in text:
        errors.append("get no longer returns nil without a store")
    else:
        print("  ok get stays nil-on-failure")

    examined += 1
    disp = root / DISPATCHER
    if disp.is_file():
        dtext = disp.read_text(encoding="utf-8", errors="replace")
        if re.search(r"idempotency\.put\([^)]+\)\s*$", dtext, re.M) or "idempotency.put(" in dtext:
            print("  ok dispatcher still discards put's return")
        else:
            errors.append("dispatcher no longer calls idempotency.put")
    else:
        errors.append("missing dispatcher")

    examined += 1
    mounts = []
    mind = root / MIND
    if mind.is_dir():
        for p in mind.rglob("*"):
            if p.suffix not in {".rb", ".yml"} or not p.is_file():
                continue
            t = p.read_text(encoding="utf-8", errors="replace")
            if "SqliteIdempotency" in t and "idempotency_store" in t:
                mounts.append(p.relative_to(root).as_posix())
    if mounts:
        errors.append("SqliteIdempotency mounted under mind-pod: %s" % mounts)
    else:
        print("  ok mind-pod does not mount SqliteIdempotency")

    ok_pop, _rec = emit_population(examined, skipped=0, skipped_reason="")
    if not ok_pop:
        return 1
    if errors:
        print("IDEMPOTENCY VISIBLE FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("idempotency visible: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
