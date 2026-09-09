#!/usr/bin/env python3
"""Fail if in-pod A2A reintroduces HTTP or a well-known Agent Card URL.

ADR 0066: A2A rides NATS. preferredTransport is NATS. MIND calls
a2a.back.rpc when MM_NATS_URL is set. HTTP is not a fallback.

Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

A2A_RB = Path("gems/rails-cpcp/lib/rails_cpcp/a2a_binding.rb")
HARNESS = Path("runtimes/mind-pod/mind/harness.py")
MIND_A2A = Path("runtimes/mind-pod/mind/mind_a2a.py")
REQUIRED = "HTTP is not a fallback"


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

    examined += 1
    rb = root / A2A_RB
    text = rb.read_text(encoding="utf-8", errors="replace") if rb.is_file() else ""
    if not text:
        errors.append("missing %s" % A2A_RB.as_posix())
    else:
        print("  ok %s" % A2A_RB.as_posix())
        if 'preferredTransport" => "NATS"' not in text and "preferredTransport'] = 'NATS'" not in text:
            if '"preferredTransport" => "NATS"' not in text:
                errors.append("Agent Card preferredTransport is not NATS")
        if "a2a.#{for_agent}.rpc" not in text and "a2a.back.rpc" not in text:
            errors.append("A2A NATS subject a2a.<agent>.rpc missing")
        if "/.well-known/" in text:
            errors.append("in-pod A2A must not serve /.well-known/agent-card")
        if REQUIRED not in text:
            errors.append("%s missing %r" % (A2A_RB.as_posix(), REQUIRED))

    examined += 1
    h = root / HARNESS
    ht = h.read_text(encoding="utf-8", errors="replace") if h.is_file() else ""
    if not ht:
        errors.append("missing %s" % HARNESS.as_posix())
    elif "a2a.back.rpc" not in ht:
        errors.append("MIND harness does not call a2a.back.rpc under MM_NATS_URL")
    else:
        print("  ok harness a2a.back.rpc")

    examined += 1
    ma = root / MIND_A2A
    mt = ma.read_text(encoding="utf-8", errors="replace") if ma.is_file() else ""
    if not mt:
        errors.append("missing %s" % MIND_A2A.as_posix())
    elif REQUIRED not in mt:
        errors.append("%s missing %r" % (MIND_A2A.as_posix(), REQUIRED))
    else:
        print("  ok %s" % MIND_A2A.as_posix())

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("A2A FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("a2a: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
