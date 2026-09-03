#!/usr/bin/env python3
"""Fail if the docs archive convention rots.

Charter 0062: live docs stay lean, history stays readable under
docs/archive/. This gate resolves every relative .md link in
docs/architecture/COVERAGE_GAPS.md (the index) and requires the archive
README. A moved finding without a repointed link fails here, not in a
reader's browser.

Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

INDEX = Path("docs/architecture/COVERAGE_GAPS.md")
README = Path("docs/archive/README.md")
LINK_RE = re.compile(r"\]\(([^)]+)\)")


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
    if not (root / README).is_file():
        errors.append("missing %s (archive convention)" % README.as_posix())
    else:
        print("  ok %s" % README.as_posix())

    examined += 1
    index = root / INDEX
    if not index.is_file():
        errors.append("missing %s" % INDEX.as_posix())
        text = ""
    else:
        text = index.read_text(encoding="utf-8", errors="replace")
        print("  ok %s" % INDEX.as_posix())

    if text:
        targets = sorted({m.group(1).split("#")[0]
                          for m in LINK_RE.finditer(text) if m.group(1).endswith(".md")})
        for target in targets:
            examined += 1
            resolved = (index.parent / target).resolve()
            try:
                resolved.relative_to(root.resolve())
            except ValueError:
                errors.append("index link escapes the repo: %s" % target)
                continue
            if not resolved.is_file():
                errors.append("index links a missing file: %s" % target)
        if not any("missing file" in e or "escapes" in e for e in errors):
            print("  ok all %d index links resolve" % len(targets))

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("DOCS ARCHIVE FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("docs archive: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
