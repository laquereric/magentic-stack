#!/usr/bin/env python3
"""Fail when a gem's Ruby names a shape gem that its gemspec does not declare.

Gap 90. check_shape_gem_deps.py only watches the two shape gemspecs
(direction). This watches CONSUMERS. Transitive is not a declaration.

Population = consumer gems examined. 0 examined is not a pass.
Empty CHECK_ROOT fails.

Does not relocate shapes. Does not reverse rails-osi-level-8 ->
shapes-application.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

SHAPE_GEMS = ("shapes-level-8", "shapes-application")
# How Ruby names a shape gem as something to resolve/require, not as prose.
NAME_RE = re.compile(
    r"""(?:require\s+["']|add(?:_runtime|_development)?_dependency\s*\(?\s*["']|=\s*["'])(shapes-level-8|shapes-application)["']"""
)
DEP_RE = re.compile(
    r"""add(?:_runtime|_development)?_dependency\s*\(?\s*["']([^"']+)["']"""
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


def gemspec_deps(path: Path):
    found = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        stripped = line.lstrip()
        if stripped.startswith("#"):
            continue
        code = stripped.split("#", 1)[0]
        found.extend(DEP_RE.findall(code))
    return found


def named_in_ruby(gem_dir: Path):
    named = set()
    lib = gem_dir / "lib"
    if not lib.is_dir():
        return named
    for p in lib.rglob("*.rb"):
        text = p.read_text(encoding="utf-8", errors="replace")
        for m in NAME_RE.finditer(text):
            named.add(m.group(1))
    return named


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

    gems_root = root / "gems"
    errors = []
    consumers = []

    if gems_root.is_dir():
        for gem_dir in sorted(p for p in gems_root.iterdir() if p.is_dir()):
            specs = list(gem_dir.glob("*.gemspec"))
            named = named_in_ruby(gem_dir)
            if not named:
                continue
            name = gem_dir.name
            # A shape gem naming itself is not a consumer of itself.
            needed = set(named)
            if name in SHAPE_GEMS:
                needed.discard(name)
            if not needed:
                continue
            consumers.append((name, needed, specs))

    examined = len(consumers)
    print("consumers", [c[0] for c in consumers])

    for name, needed, specs in consumers:
        if not specs:
            errors.append("%s names %s but has no gemspec" % (name, sorted(needed)))
            continue
        declared = set()
        for spec in specs:
            declared.update(gemspec_deps(spec))
        missing = sorted(needed - declared)
        if missing:
            errors.append(
                "%s Ruby names %s but gemspec does not declare %s (declared %s)"
                % (name, sorted(needed), missing, sorted(declared))
            )
        else:
            print("  ok %s declares %s" % (name, sorted(needed)))

    ok_pop, _rec = emit_population(
        examined, skipped=0, skipped_reason="gems whose Ruby does not name a shape gem"
    )
    if not ok_pop:
        return 1
    if errors:
        print("SHAPE CONSUMER DEPS FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("shape consumer deps: OK (%d consumers)" % examined)
    return 0


if __name__ == "__main__":
    sys.exit(main())
