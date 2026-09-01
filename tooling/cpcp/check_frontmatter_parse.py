#!/usr/bin/env python3
"""Fail if unparsable YAML is still swallowed into an empty Hash.

Gap 64. Empty YAML (`nil`) may become {}. A parse exception must not.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

SRC = Path("gems/mmg-adr/lib/mmg/adr/document.rb")
SWALLOW = re.compile(
    r"rescue\s+StandardError(?:\s*=>\s*\w+)?\s*\n\s*\{\}",
    re.M,
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
    path = root / SRC
    examined += 1
    if not path.is_file():
        errors.append("missing %s" % SRC.as_posix())
        text = ""
    else:
        text = path.read_text(encoding="utf-8", errors="replace")
        print("  ok %s" % SRC.as_posix())

    examined += 1
    if SWALLOW.search(text):
        errors.append("rescue StandardError still yields {} — unparsable YAML is swallowed")
    else:
        print("  ok rescue does not swallow into {}")

    examined += 1
    if "reason: :unparsable_frontmatter" not in text:
        errors.append("unparsable_frontmatter reason missing")
    else:
        print("  ok unparsable_frontmatter present")

    examined += 1
    if "frontmatter_not_a_mapping" not in text:
        errors.append("frontmatter_not_a_mapping reason missing")
    else:
        print("  ok frontmatter_not_a_mapping present")

    ok_pop, _rec = emit_population(examined, skipped=0, skipped_reason="")
    if not ok_pop:
        return 1
    if errors:
        print("FRONTMATTER PARSE FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("frontmatter parse: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
