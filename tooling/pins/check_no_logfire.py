#!/usr/bin/env python3
"""Fail if runtimes/ import Logfire. ADR 0058: it is a sink, not a dependency."""
from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

SKIP = {".git", "node_modules", ".venv", "vendor", "__pycache__", "dist", "tmp"}
NEEDLES = ("import logfire", "from logfire")


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
    runtimes = root / "runtimes"
    hits = []
    examined = 0
    for path in runtimes.rglob("*"):
        if any(p in SKIP for p in path.parts):
            continue
        if path.suffix not in {".py", ".rb", ".mjs", ".js", ".ts"}:
            continue
        examined += 1
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        for i, line in enumerate(text.splitlines(), 1):
            code = line.split("#", 1)[0]
            if any(n in code for n in NEEDLES):
                hits.append("%s:%d" % (path.relative_to(root).as_posix(), i))
    populated, _pop = emit_population(examined, skipped_reason="non-source under runtimes/")
    if not populated:
        return 1
    if hits:
        print("FAIL: Logfire import in runtimes/: %s" % ", ".join(hits[:10]), file=sys.stderr)
        return 1
    print("no-logfire: OK (%d files)" % examined)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
