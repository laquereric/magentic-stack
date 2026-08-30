#!/usr/bin/env python3
"""Fail when a Dockerfile FROM line is a registry image without @sha256.

A tag is documentation. The digest is the pin. The JSON record is a gate,
not a comment: every scanned pinned FROM has exactly one record, and every
record names a FROM that still exists.

Scan: gems/, runtimes/, tooling/. Exclude: .gitmodules path= plus
exclude_prefixes declared in the record file. A directory named vendor
inside gems/ is still ours. A Dockerfile neither scanned nor excluded
is a FAIL.

Intra-file stage names and ${ARG} / scratch are skipped with a reason.
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(os.environ["CHECK_ROOT"]) if os.environ.get("CHECK_ROOT") else Path(__file__).resolve().parents[2]
RECORD = ROOT / "tooling" / "pins" / "base_image_digests.json"

SCAN_PREFIXES = (
    "gems/",
    "runtimes/",
    "tooling/",
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


def follow_them_prefixes(root: Path):
    prefixes = []
    gm = root / ".gitmodules"
    if gm.is_file():
        for line in gm.read_text(encoding="utf-8", errors="replace").splitlines():
            s = line.strip()
            if s.startswith("path") and "=" in s:
                prefixes.append(s.split("=", 1)[1].strip().rstrip("/"))
    return prefixes


def load_record():
    if not RECORD.is_file():
        return None, "record file missing: %s" % RECORD
    try:
        data = json.loads(RECORD.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        return None, "record file unparseable: %s" % e
    if not isinstance(data, dict) or not isinstance(data.get("images"), list):
        return None, "record file missing images[]"
    return data, None


def classify(rel: str, follow_prefixes, declared_exclude):
    for prefix, reason in list(declared_exclude) + [(p, ".gitmodules path=") for p in follow_prefixes]:
        prefix = prefix.rstrip("/")
        if rel == prefix or rel.startswith(prefix + "/"):
            return "excluded", reason + prefix
    for prefix in SCAN_PREFIXES:
        if rel == prefix.rstrip("/") or rel.startswith(prefix):
            return "ours", None
    return "undeclared", None


def parse_from_lines(path: Path):
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
    follow = follow_them_prefixes(ROOT)
    record, rec_err = load_record()
    declared = []
    if record:
        declared = [(p, "declared exclude_prefixes: ") for p in record.get("exclude_prefixes") or []]

    examined = 0
    skipped = 0
    errors = []
    skip_reasons = []
    excluded_files = []
    undeclared = []
    pinned = []  # (rel, image)

    for path in files:
        rel = rel_posix(path, ROOT)
        kind, why = classify(rel, follow, declared)
        if kind == "excluded":
            excluded_files.append((rel, why))
            continue
        if kind == "undeclared":
            undeclared.append(rel)
            continue

        rows = parse_from_lines(path)
        stages = {name for _, _, name in rows if name}

        for lineno, image, _as in rows:
            if VAR_RE.match(image) or image == "scratch" or image in stages:
                skipped += 1
                reason = "build stage" if image in stages else "local ARG or scratch, not a registry base"
                skip_reasons.append("%s:%d %s (%s)" % (rel, lineno, image, reason))
                continue
            examined += 1
            if not DIGEST_RE.match(image):
                errors.append("%s:%d unpinned FROM %s" % (rel, lineno, image))
            else:
                pinned.append((rel, image))

    print("population: %d examined, %d skipped" % (examined, skipped))
    print("  scan=%s" % ",".join(SCAN_PREFIXES))
    print("  follow-them prefixes from .gitmodules: %d" % len(follow))
    if excluded_files:
        print("  excluded files: %d" % len(excluded_files))
        for f, why in excluded_files:
            print("    %s (%s)" % (f, why))
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

    if rec_err:
        errors.append(rec_err)
    elif record:
        images = record["images"]
        for rel, image in pinned:
            matches = [r for r in images if r.get("dockerfile") == rel and r.get("from") == image]
            if len(matches) != 1:
                errors.append(
                    "record mismatch: %s FROM %s has %d records (want 1)"
                    % (rel, image, len(matches))
                )
        for rec in images:
            df = rec.get("dockerfile") or ""
            frm = rec.get("from") or ""
            path = ROOT / df
            if not df or not path.is_file():
                errors.append("orphan record: dockerfile %r does not exist" % df)
                continue
            found = any(img == frm for _, img, _ in parse_from_lines(path))
            if not found:
                errors.append("orphan record: from %s not in %s" % (frm, df))

    if errors:
        print("BASE DIGEST FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1

    print("base digests: OK (%d registry FROM lines pinned, record agrees both ways)" % examined)
    return 0


if __name__ == "__main__":
    sys.exit(main())
