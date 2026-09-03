#!/usr/bin/env python3
"""Fail if a result-monad dependency or sentinel idiom enters the seams.

Row 70. Envelopes are owned plain data (hashes/booleans/strings/numbers/
arrays/null) so Ruby, Python, and JS can all consume them. dry-monads
would smuggle success/failure into objects truthiness misses; sentinels
do not survive serialization or language boundaries.

Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

GEM_FILES = (
    Path("Gemfile"),
    Path("runtimes/mind-pod/app/Gemfile"),
)
SEAM_DIRS = (
    Path("runtimes/mind-pod/app/app"),
    Path("runtimes/mind-pod/mind"),
    Path("runtimes/switch"),
)
SUFFIXES = (".rb", ".py", ".mjs", ".js")
SKIP_DIRS = {"vendor", "node_modules", "__pycache__", ".git"}
MONAD = re.compile(r"dry-monads|Dry::Monads|Dry::Validation|Dry::Struct")
SENTINEL = re.compile(r"SENTINEL\s*=|_sentinel\s*=|object\(\)")


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

    for rel in GEM_FILES:
        examined += 1
        p = root / rel
        text = p.read_text(encoding="utf-8", errors="replace") if p.is_file() else ""
        if not p.is_file():
            errors.append("missing %s" % rel.as_posix())
        elif MONAD.search(text):
            errors.append("%s depends on a result-monad library" % rel.as_posix())
        else:
            print("  ok %s has no monad deps" % rel.as_posix())
    for rel in [Path("gems/rails-cpcp/rails-cpcp.gemspec")]:
        examined += 1
        p = root / rel
        text = p.read_text(encoding="utf-8", errors="replace") if p.is_file() else ""
        if MONAD.search(text):
            errors.append("%s depends on a result-monad library" % rel.as_posix())
        else:
            print("  ok %s has no monad deps" % rel.as_posix())

    for top in SEAM_DIRS:
        base = root / top
        if not base.is_dir():
            errors.append("missing dir %s" % top.as_posix())
            continue
        for path in sorted(base.rglob("*")):
            if not path.is_file() or path.suffix not in SUFFIXES:
                continue
            if any(part in SKIP_DIRS for part in path.parts):
                continue
            examined += 1
            text = path.read_text(encoding="utf-8", errors="replace")
            rel = path.relative_to(root).as_posix()
            hit = SENTINEL.search(text)
            if hit:
                errors.append("%s uses a sentinel idiom" % rel)
    print("  ok seam sources scanned for sentinels")

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("NO SENTINELS FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("no sentinels: OK (plain-data envelopes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
