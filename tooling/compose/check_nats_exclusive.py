#!/usr/bin/env python3
"""Fail if an in-pod CPCP client falls back to HTTP when MM_NATS_URL is set.

ADR 0065 amendment: NATS is exclusive in-pod. Empty MM_NATS_URL still
selects HTTP (tests, host curl). A SET url that then continues to
Net::HTTP / urllib / fetch is the named defect.

Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

CLIENTS = (
    "gems/rails-cpcp/lib/rails_cpcp/nats_binding.rb",
    "runtimes/mind-pod/app/app/services/config_admin/vault_client.rb",
    "runtimes/mind-pod/app/app/services/config_admin/persist_client.rb",
    "runtimes/mind-pod/app/app/services/back_cpcp_client.rb",
    "runtimes/mind-pod/app/app/controllers/home_controller.rb",
    "runtimes/mind-pod/app/bin/backjob",
    "runtimes/mind-pod/mind/harness.py",
    "runtimes/mind-pod/mind/mind_a2a.py",
    "gems/rails-cpcp/lib/rails_cpcp/a2a_binding.rb",
    "runtimes/switch/vault.mjs",
)
REQUIRED = "HTTP is not a fallback"
FORBIDDEN = (
    "fall through to HTTP",
    "HTTP fallback",
    "dual-bind stays",
)


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
    for rel in CLIENTS:
        examined += 1
        path = root / rel
        if not path.is_file():
            errors.append("missing %s" % rel)
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        if REQUIRED not in text:
            errors.append("%s missing exclusive sentence (%r)" % (rel, REQUIRED))
        else:
            print("  ok exclusive %s" % rel)
        lower = text.lower()
        for phrase in FORBIDDEN:
            if phrase.lower() in lower:
                errors.append("%s still says %r" % (rel, phrase))

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if examined == 0:
        print("FAIL: empty client population", file=sys.stderr)
        return 1
    if errors:
        print("NATS EXCLUSIVE FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("nats exclusive: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
