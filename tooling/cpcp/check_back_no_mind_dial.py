#!/usr/bin/env python3
"""Fail if BACK depends on MIND's seam without a bounded, fallback'd pull.

Row 10 slice 5. The approved direction allows BACK to pull readings, but
BACK must still complete when MIND is down or slow (row-72 pattern), so
every BACK-side pull needs a bounded timeout and a no-reading fallback.
Today there are no BACK-side pulls at all -- this gate pins that fact:
the first one lands together with an amendment here requiring timeout +
fallback tokens beside it.

Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

APP = Path("runtimes/mind-pod/app")
SUFFIXES = (".rb", ".erb", ".builder")
SKIP_DIRS = {"spec", "tmp", "log"}
TOKENS = ("8091", "mind.reading", "mind.cognition", "mind_seam", "MIND_SEAM")


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

    base = root / APP
    if not base.is_dir():
        errors.append("missing %s" % APP.as_posix())
    else:
        files = sorted(
            p for p in base.rglob("*")
            if p.is_file() and p.suffix in SUFFIXES
            and not any(part in SKIP_DIRS for part in p.relative_to(root).parts)
        )
        if not files:
            errors.append("no app sources under %s" % APP.as_posix())
        for path in files:
            examined += 1
            text = path.read_text(encoding="utf-8", errors="replace")
            hits = sorted({t for t in TOKENS if t in text})
            if hits:
                errors.append(
                    "%s reaches for MIND's seam %s without amending this gate "
                    "(bounded timeout plus no-reading fallback required)"
                    % (path.relative_to(root).as_posix(), hits)
                )
    if not errors:
        print("  ok BACK completes without MIND (%d files)" % examined)

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("BACK NO MIND DIAL FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("back needs no mind: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
