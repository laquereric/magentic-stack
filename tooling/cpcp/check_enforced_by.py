#!/usr/bin/env python3
"""Resolve and classify every in-force ADR's enforced_by / stand_in.

Gap 96. Presence is not resolution. A doc is not a gate. A stand-in is
not enforcement.

  enforcing -- a checker, spec, or workflow: something that RUNS and can fail
  declaring -- compose / config: the rule lives here
  neither   -- a doc, a bare directory, library source

Every accepted (not superseded) ADR must name at least one ENFORCING
target, or set unenforced: true with unenforced_because. neither must
not appear in enforced_by. stand_in is a separate list and never
counts as enforcing.

Population: ADRs examined AND refs examined, both printed.
Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

ADR_DIR = Path("docs/adr")


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


def frontmatter(text: str) -> str:
    m = re.search(r"^---\n(.*?)\n---", text, re.S)
    return m.group(1) if m else ""


def field(fm: str, name: str):
    m = re.search(r"^%s:\s*(.*)$" % re.escape(name), fm, re.M)
    return m.group(1).strip() if m else None


def list_field(fm: str, name: str):
    m = re.search(r"^%s:\s*\n((?:  - .*\n)*)" % re.escape(name), fm, re.M)
    if m:
        return [re.sub(r"^  - ", "", line).strip() for line in m.group(1).splitlines() if line.strip()]
    m = re.search(r"^%s:\s*\[(.*)\]\s*$" % re.escape(name), fm, re.M)
    if m:
        inner = m.group(1).strip()
        if not inner:
            return []
        return [x.strip().strip("'\"") for x in inner.split(",") if x.strip()]
    return []


def classify(path: Path) -> str:
    if not path.exists():
        return "missing"
    if path.is_dir():
        return "neither"
    parts = path.parts
    name = path.name
    if "workflows" in parts and path.suffix in (".yml", ".yaml"):
        return "enforcing"
    if path.suffix == ".py" and (
        name.startswith("check_")
        or name.startswith("plant_")
        or name.endswith("_test.py")
        or "spec" in parts
        or "test" in parts
        or "scripts" in parts
        or "tooling" in parts
    ):
        return "enforcing"
    if path.suffix == ".rb" and (name.endswith("_spec.rb") or "spec" in parts):
        return "enforcing"
    if path.suffix in (".mjs", ".js") and ("test" in parts or ".test." in name):
        return "enforcing"
    if name in ("spec-all", "prereq") or (len(parts) >= 2 and parts[-2] == "bin"):
        return "enforcing"
    if "docker-compose" in name or name == "compose.yml" or name == "Dockerfile":
        return "declaring"
    if path.suffix in (".json", ".yml", ".yaml") and "config" in parts:
        return "declaring"
    return "neither"


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

    adr_dir = root / ADR_DIR
    files = sorted(adr_dir.glob("[0-9]*.md")) if adr_dir.is_dir() else []
    errors = []
    adrs = 0
    refs = 0
    counts = {"enforcing": 0, "declaring": 0, "neither": 0, "missing": 0}

    for path in files:
        fm = frontmatter(path.read_text(encoding="utf-8", errors="replace"))
        status = (field(fm, "status") or "").lower()
        if status != "accepted":
            continue
        adrs += 1
        aid = path.name[:4]
        ebs = list_field(fm, "enforced_by")
        stands = list_field(fm, "stand_in")
        unenf = (field(fm, "unenforced") or "").lower() in ("true", "yes")
        because = field(fm, "unenforced_because") or ""

        enforcing = []
        for rel in ebs:
            refs += 1
            kind = classify(root / rel)
            counts[kind] = counts.get(kind, 0) + 1
            print("  %s enforced_by %s -> %s" % (aid, rel, kind))
            if kind == "missing":
                errors.append("%s enforced_by missing: %s" % (aid, rel))
            elif kind == "neither":
                errors.append("%s enforced_by is neither (doc/dir/lib): %s" % (aid, rel))
            elif kind == "enforcing":
                enforcing.append(rel)

        for rel in stands:
            refs += 1
            kind = classify(root / rel)
            # stand_in may be any existing path; missing is still a fail
            print("  %s stand_in %s -> %s" % (aid, rel, kind))
            if kind == "missing":
                errors.append("%s stand_in missing: %s" % (aid, rel))

        if unenf:
            if not because.strip():
                errors.append("%s unenforced without unenforced_because" % aid)
            else:
                print("  %s unenforced: %s" % (aid, because))
        elif not enforcing:
            errors.append(
                "%s in-force with no enforcing target (and not unenforced)" % aid
            )

    print("  adrs examined: %d" % adrs)
    print("  refs examined: %d" % refs)
    print("  class enforcing=%d declaring=%d neither=%d missing=%d" % (
        counts["enforcing"], counts["declaring"], counts["neither"], counts["missing"]))
    ok_pop, _ = emit_population(adrs + refs, skipped=0)
    if not ok_pop:
        return 1
    if adrs == 0 or refs == 0:
        print("FAIL: empty adrs or refs population", file=sys.stderr)
        return 1
    if errors:
        print("ENFORCED_BY FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("enforced_by: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
