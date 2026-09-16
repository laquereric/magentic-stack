#!/usr/bin/env python3
"""R8: mind-pod schema does not grow story_* tables.

StoryTime owns /data/storytime.sqlite3 in the overlay. A story_ table
in mind-pod is a multi-app tenant schema, which ADR 0063 forbids.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population  # noqa: E402

ROOT = Path(os.environ["CHECK_ROOT"]) if os.environ.get("CHECK_ROOT") else Path(__file__).resolve().parents[2]
SCHEMA = ROOT / "runtimes/mind-pod/app/db/schema.rb"
MIG = ROOT / "runtimes/mind-pod/app/db/migrate"
CREATE_STORY = re.compile(r"""create_table\s+["':]story_""")

errors: list[str] = []


def main() -> int:
    files: list[Path] = []
    if SCHEMA.is_file():
        files.append(SCHEMA)
    if MIG.is_dir():
        files.extend(sorted(p for p in MIG.glob("*.rb") if p.is_file()))

    populated, _ = emit_population(len(files))
    if not populated:
        return 1

    for path in files:
        text = path.read_text(encoding="utf-8", errors="replace")
        if CREATE_STORY.search(text):
            errors.append(
                "%s creates a story_ table; overlay persistence is per-application "
                "(R8, ADR 0063). reason=shared_schema_refused"
                % path.relative_to(ROOT).as_posix()
            )

    if errors:
        print("FAIL: no-story-tables-in-mind-pod (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  %s" % e, file=sys.stderr)
        return 1
    print("no-story-tables-in-mind-pod: OK (%d files)" % len(files))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
