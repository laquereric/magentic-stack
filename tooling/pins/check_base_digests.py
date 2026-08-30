#!/usr/bin/env python3
"""Fail when a Dockerfile FROM line is a registry image without @sha256.

A tag is documentation. The digest is the pin. A rebuild months later from
the same commit must not silently pick up a retagged base.

Local ARG FROM (FROM ${BASE}) is skipped with a reason -- those names are
our own images, reassigned on every build; pinning them is a different
problem (artifact identity). Registry bases must carry an index digest.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

ROOT = Path(os.environ["CHECK_ROOT"]) if os.environ.get("CHECK_ROOT") else Path(__file__).resolve().parents[2]

FROM_RE = re.compile(
    r"^\s*FROM\s+(?:--platform=\S+\s+)?(\S+)(?:\s+AS\s+\S+)?\s*$",
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


def parse_from_lines(path: Path):
    rows = []
    for i, raw in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        m = FROM_RE.match(line)
        if not m:
            continue
        rows.append((i, m.group(1)))
    return rows


def main():
    files = dockerfiles(ROOT)
    examined = 0
    skipped = 0
    errors = []
    skip_reasons = []

    for path in files:
        rel = path.relative_to(ROOT)
        for lineno, image in parse_from_lines(path):
            if VAR_RE.match(image) or image == "scratch":
                skipped += 1
                skip_reasons.append("%s:%d %s (local ARG or scratch, not a registry base)" % (rel, lineno, image))
                continue
            examined += 1
            if not DIGEST_RE.match(image):
                errors.append("%s:%d unpinned FROM %s" % (rel, lineno, image))

    print("population: %d examined, %d skipped" % (examined, skipped))
    if skip_reasons:
        for s in skip_reasons:
            print("  skipped " + s)

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
