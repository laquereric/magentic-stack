#!/usr/bin/env python3
"""Fail when a Dockerfile FROM line is a registry image without @sha256.

A tag is documentation. The digest is the pin. A rebuild months later from
the same commit must not silently pick up a retagged base.

The scan boundary is a DECLARED list, not a glob. Dockerfiles under
upstreams/ and vendored trees are FOLLOW-THEM / do-not-fork: we do not pin
them, and we do not pretend they were not there. A Dockerfile that is
neither in the scanned set nor the exclusion list is a FAIL -- the same
shape as the shape-scope boundary.

Intra-file stage names (FROM python AS base, then FROM base) are not
images. Neither are ${ARG} local bases or scratch.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

ROOT = Path(os.environ["CHECK_ROOT"]) if os.environ.get("CHECK_ROOT") else Path(__file__).resolve().parents[2]

# Ours. A new Dockerfile under these prefixes is examined.
SCAN_PREFIXES = (
    "gems/",
    "runtimes/",
    "tooling/",
)

# Not ours to pin. DO NOT FORK. Exclusion wins over scan when both match
# (runtimes/mind-pod/mind/vendor/ is under runtimes/).
EXCLUDE_PREFIXES = (
    "upstreams/",
    "runtimes/mind-pod/mind/vendor/",
)

FROM_RE = re.compile(
    r"^\s*FROM\s+(?:--platform=\S+\s+)?(\S+)(?:\s+AS\s+(\S+))?\s*$",
    re.IGNORECASE,
)
DIGEST_RE = re.compile(r".+@sha256:[0-9a-f]{64}$", re.IGNORECASE)
VAR_RE = re.compile(r"^\$\{[A-Za-z_][A-Za-z0-9_]*\}$")


def dockerfiles(root: Path):
    out = []
    for p in root.rglob("Dockerfile"):
        if ".git" in p.parts:
            continue
        out.append(p)
    for p in root.rglob("Dockerfile.*"):
        if ".git" in p.parts:
            continue
        out.append(p)
    return sorted(set(out))


def rel_posix(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def classify(rel: str) -> str:
    for prefix in EXCLUDE_PREFIXES:
        if rel == prefix.rstrip("/") or rel.startswith(prefix):
            return "excluded"
    for prefix in SCAN_PREFIXES:
        if rel == prefix.rstrip("/") or rel.startswith(prefix):
            return "ours"
    return "undeclared"


def parse_from_lines(path: Path):
    """Return (lineno, image, stage_name_or_None) for each FROM."""
    rows = []
    for i, raw in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        m = FROM_RE.match(line)
        if not m:
            continue
        rows.append((i, m.group(1), m.group(2)))
    return rows


def main():
    files = dockerfiles(ROOT)
    examined = 0
    skipped = 0
    errors = []
    skip_reasons = []
    excluded_files = []
    undeclared = []

    for path in files:
        rel = rel_posix(path, ROOT)
        kind = classify(rel)
        if kind == "excluded":
            excluded_files.append(rel)
            continue
        if kind == "undeclared":
            undeclared.append(rel)
            continue

        rows = parse_from_lines(path)
        stages = {name for _, _, name in rows if name}

        for lineno, image, _as in rows:
            if VAR_RE.match(image) or image == "scratch" or image in stages:
                skipped += 1
                why = "build stage" if image in stages else "local ARG or scratch, not a registry base"
                skip_reasons.append("%s:%d %s (%s)" % (rel, lineno, image, why))
                continue
            examined += 1
            if not DIGEST_RE.match(image):
                errors.append("%s:%d unpinned FROM %s" % (rel, lineno, image))

    print("population: %d examined, %d skipped" % (examined, skipped))
    print("  scan=%s" % ",".join(SCAN_PREFIXES))
    print("  exclude=%s" % ",".join(EXCLUDE_PREFIXES))
    if excluded_files:
        print("  excluded files: %d" % len(excluded_files))
        for f in excluded_files:
            print("    " + f)
    if skip_reasons:
        for s in skip_reasons:
            print("  skipped " + s)

    if undeclared:
        print("BASE DIGEST FAIL: Dockerfile neither scanned nor excluded", file=sys.stderr)
        for f in undeclared:
            print("  undeclared %s" % f, file=sys.stderr)
        return 1

    if examined == 0:
        print("FAIL: empty population -- 0 examined is not a pass", file=sys.stderr)
        return 1

    if errors:
        print("BASE DIGEST FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1

    print("base digests: OK (%d registry FROM lines pinned)" % examined)
    return 0


if __name__ == "__main__":
    sys.exit(main())
