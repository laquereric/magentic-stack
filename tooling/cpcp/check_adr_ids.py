#!/usr/bin/env python3
"""No two ADRs claim one id, and the filename agrees with the field.

WHY THIS EXISTS AT SWEEP TIME. mmg-adr's ingest already catches a duplicate id
-- it did, twice in five days (0070, then 0071 on a branch that already
contained the first renumber). But it catches it at MERGE time, when the whole
branch has been built on top of the collision, and each renumber then costs six
or seven reference sites: the id field, the H1, a gate that names the ADR by
path, a planter docstring, and every doc that links the filename.

Detecting the same fact at commit time costs one rename. That is the entire
argument for this file; it computes nothing the ingest does not.

Two rules, and the second is the one that bites in parallel work:

  UNIQUE ID      two files claiming one `id:` is the collision itself.

  NAME AGREES    `0072-front-is-bun.md` must carry `id: "0072"`. A renumber
                 that moves the filename and forgets the field, or the reverse,
                 leaves a file that reads correct in a directory listing and
                 wrong to every consumer -- which is worse than either mistake
                 alone, because the listing is what a human checks.

FAILS CLOSED: no docs/adr, or zero ADRs, is an error. A green run over an empty
corpus would mean nothing.
"""
from __future__ import annotations

import os
import re
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population  # noqa: E402

ROOT = Path(os.environ["CHECK_ROOT"]) if os.environ.get("CHECK_ROOT") else Path(__file__).resolve().parents[2]
ADR_DIR = ROOT / "docs/adr"

ID_FIELD = re.compile(r'^id:\s*"?([0-9]{4})"?\s*$', re.M)
FILENAME_ID = re.compile(r"^([0-9]{4})-")

errors: list[str] = []


def main() -> int:
    if not ADR_DIR.is_dir():
        print("FAIL: no docs/adr at %s" % ADR_DIR, file=sys.stderr)
        emit_population(0)
        return 1

    files = sorted(p for p in ADR_DIR.glob("*.md") if FILENAME_ID.match(p.name))
    populated, _pop = emit_population(len(files), skipped_reason="no numbered ADRs")
    if not populated:
        return 1

    by_id: dict[str, list[str]] = defaultdict(list)

    for path in files:
        name = path.name
        text = path.read_text(encoding="utf-8", errors="replace")

        m = ID_FIELD.search(text)
        if not m:
            errors.append("%s has no `id:` field; it cannot be checked for collision" % name)
            continue

        declared = m.group(1)
        from_name = FILENAME_ID.match(name).group(1)
        by_id[declared].append(name)

        if declared != from_name:
            errors.append(
                "%s declares id %s -- the filename says %s. A directory listing is what a "
                "human checks, so a file that reads right there and wrong to every consumer "
                "is worse than either half being wrong alone" % (name, declared, from_name)
            )

    for adr_id, names in sorted(by_id.items()):
        if len(names) > 1:
            errors.append(
                "id %s is claimed by %d files: %s. Two records under one id look to the "
                "ingest like one record being edited" % (adr_id, len(names), ", ".join(names))
            )

    if errors:
        for e in errors:
            print("  FAIL %s" % e, file=sys.stderr)
        print("adr ids: FAIL (%d)" % len(errors), file=sys.stderr)
        return 1

    print("adr ids: OK (%d ADRs, %d distinct ids)" % (len(files), len(by_id)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
