#!/usr/bin/env python3
"""R7: StoryTime is not a magentic-stack gem.

docs/architecture/plan_vv-storytime.md. check_closed.py is insufficient:
a gemspec whose homepage is magentic-stack PASSES that gate. This one
fails if gems/vv-storytime/ exists or any gemspec is named vv-storytime
or storytime.

The overlay slot `storytime` is named here (APPLICATIONS + empty
contracts/storytime/). Overlay shapes stay in the overlay repo.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population  # noqa: E402

ROOT = Path(os.environ["CHECK_ROOT"]) if os.environ.get("CHECK_ROOT") else Path(__file__).resolve().parents[2]
VENDOR_DIRS = ("gems", "tooling", "runtimes")
FORBIDDEN_DIR = ROOT / "gems/vv-storytime"
FORBIDDEN_NAMES = frozenset({"vv-storytime", "storytime"})
APP_RB = ROOT / "gems/shapes-application/lib/shapes-application.rb"
SLOT = ROOT / "gems/shapes-application/contracts/storytime"
NAME_RE = re.compile(r"""s\.name\s*=\s*["']([^"']+)["']""")

errors: list[str] = []


def gemspecs() -> list[Path]:
    out: list[Path] = []
    for d in VENDOR_DIRS:
        base = ROOT / d
        if base.is_dir():
            out.extend(sorted(base.glob("*/*.gemspec")))
    return out


def main() -> int:
    specs = gemspecs()
    populated, _ = emit_population(len(specs) + 2)  # gemspecs + deny-dir + slot
    if not populated:
        return 1

    if FORBIDDEN_DIR.exists():
        errors.append(
            "gems/vv-storytime/ exists; StoryTime is an overlay (ADR 0063), "
            "not a substrate gem (R7). reason=storytime_is_not_a_substrate_gem"
        )

    for spec in specs:
        text = spec.read_text(encoding="utf-8", errors="replace")
        m = NAME_RE.search(text)
        if not m:
            continue
        name = m.group(1)
        if name in FORBIDDEN_NAMES:
            errors.append(
                "%s names %r; forbidden on the substrate (R7). "
                "reason=storytime_is_not_a_substrate_gem"
                % (spec.relative_to(ROOT).as_posix(), name)
            )

    if not APP_RB.is_file():
        errors.append("missing %s" % APP_RB.relative_to(ROOT).as_posix())
    else:
        body = APP_RB.read_text(encoding="utf-8")
        if "storytime" not in body or "APPLICATIONS" not in body:
            errors.append("shapes-application APPLICATIONS does not name storytime")
        elif not re.search(r"APPLICATIONS\s*=\s*%w\[[^\]]*storytime", body):
            errors.append("APPLICATIONS array does not include storytime")

    readme = SLOT / "README.md"
    if not SLOT.is_dir() or not readme.is_file():
        errors.append("missing contracts/storytime/README.md; the slot names the overlay")
    else:
        ttls = sorted(p for p in SLOT.rglob("*.ttl") if p.is_file())
        if ttls:
            errors.append(
                "contracts/storytime/ holds TTL (%s); ADR 0063 amendment: "
                "application shapes live in the overlay"
                % ", ".join(p.relative_to(ROOT).as_posix() for p in ttls)
            )

    if errors:
        print("FAIL: no-storytime-gem (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  %s" % e, file=sys.stderr)
        return 1
    print("no-storytime-gem: OK (%d gemspecs)" % len(specs))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
