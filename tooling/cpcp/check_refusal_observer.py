#!/usr/bin/env python3
"""Fail if the ADR 0054 refusal collector is missing or unhooked.

The cheap shape (gap 63 step 2): one collector, not 29 site edits.
Dispatcher must call RefusalLog.observe_envelope so Envelope.fail and
nested {ok:false} are written to a durable JSONL.

A missing heartbeat is a FAIL — that is distinguishable from zero
refusals (the observer never ran). Empty CHECK_ROOT fails.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

DISPATCHER = "gems/rails-cpcp/lib/rails_cpcp/dispatcher.rb"
REFUSAL_LOG = "gems/rails-cpcp/lib/rails_cpcp/refusal_log.rb"
NEEDLES = (
    "RefusalLog.observe_envelope",
    "unknown_operation",
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

    log_path = root / REFUSAL_LOG
    examined += 1
    if not log_path.is_file():
        errors.append("missing %s" % REFUSAL_LOG)
    else:
        print("  ok %s" % REFUSAL_LOG)

    disp = root / DISPATCHER
    examined += 1
    if not disp.is_file():
        errors.append("missing %s" % DISPATCHER)
        text = ""
    else:
        text = disp.read_text(encoding="utf-8", errors="replace")
        print("  ok %s" % DISPATCHER)

    for needle in NEEDLES:
        examined += 1
        if needle in text:
            print("  ok dispatcher contains %s" % needle)
        else:
            errors.append("%s does not call/contain %s" % (DISPATCHER, needle))

    log_text = log_path.read_text(encoding="utf-8", errors="replace") if log_path.is_file() else ""
    for needle in ("def rotate!", "def status", "KEEP_GENERATIONS", "floor_rotated"):
        examined += 1
        if needle in log_text:
            print("  ok refusal log contains %s" % needle)
        else:
            errors.append("%s is missing bounded-floor %s (rows 86/87)" % (REFUSAL_LOG, needle))

    skipped = 0
    skip_reason = ""
    hb = os.environ.get("CPCP_REFUSAL_HEARTBEAT", "").strip()
    if hb:
        examined += 1
        if not Path(hb).is_file():
            errors.append("observer did not run (missing heartbeat %s)" % hb)
        else:
            print("  ok heartbeat %s" % hb)
    else:
        skipped += 1
        skip_reason = "CPCP_REFUSAL_HEARTBEAT unset; source half only"
        print("  skip heartbeat (%s)" % skip_reason)

    ok_pop, _rec = emit_population(examined, skipped=skipped, skipped_reason=skip_reason)
    if not ok_pop:
        return 1
    if errors:
        print("REFUSAL OBSERVER FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("refusal observer: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
