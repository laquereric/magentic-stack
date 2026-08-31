#!/usr/bin/env python3
"""Fail when packaged-vs-legacy bytes change without updating the record.

Gap 67. Does NOT strip comments. Does NOT compare through a loosened
hasher. A real byte change (comment OR sh:ignoredProperties OR minCount)
moves the sha256 and this checker FAILs until packaged_vs_legacy.json is
updated on purpose.

Empty CHECK_ROOT fails.
"""
from __future__ import annotations

import hashlib
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

RECORD = Path("tooling/shacl/packaged_vs_legacy.json")


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


def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    h.update(p.read_bytes())
    return h.hexdigest()


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
    rec_path = root / RECORD
    examined += 1
    if not rec_path.is_file():
        errors.append("missing %s" % RECORD.as_posix())
        pairs = []
    else:
        doc = json.loads(rec_path.read_text(encoding="utf-8"))
        pairs = doc.get("pairs") or []
        print("  ok %s (%d pairs)" % (RECORD.as_posix(), len(pairs)))

    if not pairs:
        errors.append("no pairs recorded")

    for pair in pairs:
        for side, key in (("legacy", "legacy_sha256"), ("packaged", "packaged_sha256")):
            rel = pair.get(side)
            examined += 1
            p = root / rel if rel else None
            if not rel or not p.is_file():
                errors.append("missing %s file %s" % (side, rel))
                continue
            got = sha256_file(p)
            want = pair.get(key)
            if got != want:
                errors.append(
                    "%s %s hash moved: live=%s recorded=%s (%s). "
                    "If the delta is intentional, update packaged_vs_legacy.json. "
                    "Do not strip comments to make this pass."
                    % (pair.get("id"), side, got, want, rel)
                )
            else:
                print("  ok %s %s %s" % (pair.get("id"), side, got[:12]))
        examined += 1
        identical = pair.get("byte_identical")
        if identical and pair.get("legacy_sha256") != pair.get("packaged_sha256"):
            errors.append("%s claims byte_identical but hashes differ" % pair.get("id"))
        if identical is False and pair.get("legacy_sha256") == pair.get("packaged_sha256"):
            errors.append("%s claims not identical but hashes match" % pair.get("id"))

    ok_pop, _rec = emit_population(examined, skipped=0, skipped_reason="")
    if not ok_pop:
        return 1
    if errors:
        print("PACKAGED LEGACY FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("packaged-legacy: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
