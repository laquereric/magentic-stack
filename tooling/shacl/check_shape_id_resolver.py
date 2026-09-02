#!/usr/bin/env python3
"""Fail if historical shape_id is rewritten, guessed, or mapped from a second table.

Gap 22 / ADR 0060. Resolver on read. Mapping file is the single source.
Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

MAPPING = Path("tooling/shacl/osi_example_successors.json")
RESOLVER = Path("gems/rails-osi-level-8/lib/rails_osi_level_8/shape_id.rb")
PROJECTIONS = Path("gems/rails-osi-level-8/lib/rails_osi_level_8/projections.rb")
OLD = "https://osi.example/shapes/P1NoteCreateEffectShape"
NEW = "https://w3id.org/cpcp/osi8/note#P1NoteCreateEffectShape"
UPDATE = re.compile(r"\bUPDATE\b|\.update!|\.update_all\b|\.update\(", re.I)


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


def code_only(text: str) -> str:
    return "\n".join(line.split("#", 1)[0] for line in text.splitlines())


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

    examined += 1
    mpath = root / MAPPING
    if not mpath.is_file():
        errors.append("missing %s (the single mapping)" % MAPPING.as_posix())
    else:
        print("  ok %s" % MAPPING.as_posix())

    examined += 1
    copies = []
    for p in root.rglob("osi_example_successors.json"):
        try:
            rel = p.relative_to(root).as_posix()
        except ValueError:
            continue
        if any(part in {".git", "vendor", "node_modules", ".bundle", "tmp"} for part in p.relative_to(root).parts):
            continue
        copies.append(rel)
    if copies != [MAPPING.as_posix()]:
        errors.append("mapping must have exactly one home %s, found %s" % (MAPPING.as_posix(), copies))
    else:
        print("  ok mapping has one home")

    examined += 1
    rpath = root / RESOLVER
    src = rpath.read_text(encoding="utf-8", errors="replace") if rpath.is_file() else ""
    if not src:
        errors.append("missing %s" % RESOLVER.as_posix())
    else:
        print("  ok %s" % RESOLVER.as_posix())
    code = code_only(src)
    if MAPPING.as_posix() not in src:
        errors.append("resolver does not name %s" % MAPPING.as_posix())
    if OLD in code:
        errors.append("resolver inlines a successor table (second copy)")
    if "shape_id_unresolved" not in src:
        errors.append("resolver does not name unresolved")
    if "historical" not in src or "current" not in src:
        errors.append("resolver missing historical/current")
    if UPDATE.search(code):
        errors.append("resolver writes history")

    examined += 1
    proj = (root / PROJECTIONS).read_text(encoding="utf-8", errors="replace") if (root / PROJECTIONS).is_file() else ""
    if not proj:
        errors.append("missing %s" % PROJECTIONS.as_posix())
    elif "ShapeId.resolve" not in proj:
        errors.append("context_list does not resolve shape_id on read")
    else:
        print("  ok context_list resolves on read")
    if UPDATE.search(code_only(proj)):
        errors.append("projections write history")

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("SHAPE ID RESOLVER FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("shape id resolver: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
