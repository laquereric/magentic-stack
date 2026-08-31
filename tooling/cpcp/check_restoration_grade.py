#!/usr/bin/env python3
"""Fail if restoration-grade refusals grew an OTEL translation layer, or
if the one new attribute key is unstated / half-filled.

Gap 74 + ADR 0058 ruling:
  do not reformat OTEL; SHACL only for required NEW metadata; prefer none.

This checker:

  1. RefusalLog.record accepts restoration and compact_restoration drops
     a partial object (absent, not a half record).
  2. otel.scope.version is emitted (OTEL-native schema_version).
  3. The only SHACL under rails-cpcp/shapes is cpcp-restoration (no
     otel:LogRecord shape — that would be the translation layer).
  4. JSONL never invents trace_id / span_id / container_id / SeverityNumber.

Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

REFUSAL_LOG = Path("gems/rails-cpcp/lib/rails_cpcp/refusal_log.rb")
SHAPE = Path("gems/rails-cpcp/shapes/cpcp-restoration.shacl.ttl")
SHAPES_DIR = Path("gems/rails-cpcp/shapes")
FORBIDDEN_SHAPE_NEEDLES = ("otel:LogRecord", "otel:logrecord", "LogRecordShape")
FORBIDDEN_JSON_KEYS = ("trace_id", "span_id", "container_id", "SeverityNumber")
RECORD_NEEDLES = (
    "restoration: nil",
    "def compact_restoration",
    '"otel.scope.version"',
    '"cpcp.restoration"',
    "RESTORATION_KEYS",
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
    skipped = 0
    skip_reason = ""

    log_path = root / REFUSAL_LOG
    examined += 1
    if not log_path.is_file():
        errors.append("missing %s" % REFUSAL_LOG.as_posix())
        text = ""
    else:
        text = log_path.read_text(encoding="utf-8", errors="replace")
        print("  ok %s" % REFUSAL_LOG.as_posix())

    for needle in RECORD_NEEDLES:
        examined += 1
        if needle in text:
            print("  ok RefusalLog contains %s" % needle)
        else:
            errors.append("%s missing %s" % (REFUSAL_LOG.as_posix(), needle))

    examined += 1
    if "return nil if text.empty?" in text:
        print("  ok compact_restoration drops empty members")
    else:
        errors.append("compact_restoration does not drop partial restoration")

    shape = root / SHAPE
    examined += 1
    if not shape.is_file():
        errors.append("missing %s" % SHAPE.as_posix())
        shape_text = ""
    else:
        shape_text = shape.read_text(encoding="utf-8", errors="replace")
        print("  ok %s" % SHAPE.as_posix())

    for needle in ("cpcp:RestorationShape", "sh:closed true", "cpcp:stateReached",
                   "cpcp:inconsistency", "cpcp:restoreWhen", "cpcp:restoreAction"):
        examined += 1
        if needle in shape_text:
            print("  ok shape contains %s" % needle)
        else:
            errors.append("%s missing %s" % (SHAPE.as_posix(), needle))

    examined += 1
    shapes_dir = root / SHAPES_DIR
    if shapes_dir.is_dir():
        hits = []
        for p in shapes_dir.rglob("*"):
            if not p.is_file():
                continue
            body = p.read_text(encoding="utf-8", errors="replace")
            for n in FORBIDDEN_SHAPE_NEEDLES:
                if n.lower() in body.lower():
                    hits.append("%s:%s" % (p.relative_to(root).as_posix(), n))
        if hits:
            errors.append("OTEL LogRecord shape present (translation layer): %s" % hits)
        else:
            print("  ok no otel:LogRecord shape under %s" % SHAPES_DIR.as_posix())
    else:
        errors.append("missing %s" % SHAPES_DIR.as_posix())

    for key in FORBIDDEN_JSON_KEYS:
        examined += 1
        # assignment of a fabricated field on the event hash
        probe = '"%s"' % key
        if probe in text and ("event[%s]" % probe in text or '"%s" =>' % key in text):
            errors.append("RefusalLog writes fabricated field %s" % key)
        else:
            print("  ok RefusalLog does not emit %s" % key)

    ok_pop, _rec = emit_population(examined, skipped=skipped, skipped_reason=skip_reason)
    if not ok_pop:
        return 1
    if errors:
        print("RESTORATION GRADE FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("restoration grade: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
