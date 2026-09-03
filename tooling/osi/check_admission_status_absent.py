#!/usr/bin/env python3
"""Fail if admission_status is still read or written in code.

The column is gone (ADR 0052). A leftover predicate would resurrect the lie.
Scan Ruby and extensionless bin scripts. Docs and the drop migration may still
name the column. Empty CHECK_ROOT fails.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

NEEDLE = re.compile(r"admission_status")
SCAN_PREFIXES = ("gems/", "runtimes/", "tooling/")
SKIP_DIR = {".git", "vendor", "node_modules"}
ALLOW_REL = (
    "gems/rails-osi-level-8/db/migrate/20260819090006_create_osi_l8_operation_requests.rb",
    "gems/rails-osi-level-8/db/migrate/20260831120001_remove_osi_l8_admission_status.rb",
    "gems/rails-osi-level-8/db/dumps/0052-pre-drop.json",
    "tooling/osi/check_admission_status_absent.py",
    "tooling/osi/check_admission_indeterminate.py",
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


def is_code(path: Path) -> bool:
    if path.suffix == ".rb":
        return True
    if path.parent.name == "bin" and path.suffix == "":
        return True
    if path.name == "schema.rb":
        return True
    return False


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

    files = []
    for p in root.rglob("*"):
        if not p.is_file():
            continue
        rel_parts = p.relative_to(root).parts
        if any(part in SKIP_DIR for part in rel_parts):
            continue
        rel = p.relative_to(root).as_posix()
        if not any(rel == pre.rstrip("/") or rel.startswith(pre) for pre in SCAN_PREFIXES):
            continue
        if is_code(p):
            files.append(p)

    ok_pop, _ = emit_population(len(files))
    if not ok_pop:
        return 1

    errors = []
    for p in files:
        rel = p.relative_to(root).as_posix()
        if rel in ALLOW_REL:
            continue
        text = p.read_text(encoding="utf-8", errors="replace")
        for i, line in enumerate(text.splitlines(), 1):
            if NEEDLE.search(line.split("#", 1)[0]):
                errors.append("%s:%d %s" % (rel, i, line.strip()))

    if errors:
        print("ADMISSION_STATUS ABSENT FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("admission_status absent: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
