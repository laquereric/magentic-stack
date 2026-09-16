#!/usr/bin/env python3
"""D15: substrate CPCP/LinkML manifests do not name story.*.

Overlay methods stay in the overlay. Adding them here is the substrate
naming its consumers — the ADR 0063 amendment failure mode.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population  # noqa: E402

ROOT = Path(os.environ["CHECK_ROOT"]) if os.environ.get("CHECK_ROOT") else Path(__file__).resolve().parents[2]
MANIFESTS = (
    ROOT / "tooling/cpcp/boundary_manifest.json",
    ROOT / "tooling/cpcp/seam_authority.json",
    ROOT / "tooling/cpcp/cpcp_callers.json",
    ROOT / "tooling/linkml/sources.json",
)
STORY_DOT = re.compile(r"\bstory\.")

errors: list[str] = []


def main() -> int:
    missing = [p for p in MANIFESTS if not p.is_file()]
    present = [p for p in MANIFESTS if p.is_file()]
    populated, _ = emit_population(len(present), skipped=len(missing),
                                   skipped_reason="manifest missing")
    if missing:
        for p in missing:
            errors.append("missing %s" % p.relative_to(ROOT).as_posix())
        print("FAIL: no-story-in-substrate-cpcp (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  %s" % e, file=sys.stderr)
        return 1
    if not populated:
        return 1

    for path in present:
        text = path.read_text(encoding="utf-8", errors="replace")
        if STORY_DOT.search(text):
            errors.append(
                "%s names story.*; overlay CPCP stays in the overlay "
                "(D15, ADR 0063). reason=substrate_names_its_consumer"
                % path.relative_to(ROOT).as_posix()
            )

    if errors:
        print("FAIL: no-story-in-substrate-cpcp (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  %s" % e, file=sys.stderr)
        return 1
    print("no-story-in-substrate-cpcp: OK (%d manifests)" % len(present))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
