#!/usr/bin/env python3
"""Fail if storable_models still returns [] for both error and empty.

Gap 68 U5. Discovery refusal must be :storable_discovery_failed.
Legitimate empty catalogue stays :no_storable_models. run must
forward the discovery reason, not convert it.

Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

SRC = Path("runtimes/mind-pod/app/app/services/graph_replay.rb")
SWALLOW = re.compile(
    r"rescue\s+StandardError(?:\s*=>\s*\w+)?\s*\n\s*\[\]",
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


def method_body(text: str, name: str):
    m = re.search(
        r"^([ \t]*)def (?:self\.)?%s(?:\s|\(|$)" % re.escape(name),
        text,
        re.M,
    )
    if not m:
        return None
    indent = m.group(1)
    start = m.end()
    nxt = re.search(
        r"^%sdef |\n%sprivate\b|\n%sclass |\n%send\b" % (indent, indent, indent, indent),
        text[start:],
        re.M,
    )
    end = start + nxt.start() if nxt else len(text)
    return text[m.start():end]


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
    body = method_body(text, "storable_models") if text else None
    if not body:
        errors.append("GraphReplay missing storable_models")
    elif SWALLOW.search(body):
        errors.append("storable_models rescue still yields [] — discovery error looks empty")
    else:
        print("  ok storable_models rescue does not yield []")

    examined += 1
    if ":storable_discovery_failed" not in text:
        errors.append("storable_discovery_failed reason missing")
    else:
        print("  ok storable_discovery_failed present")

    examined += 1
    if ":no_storable_models" not in text:
        errors.append("no_storable_models reason missing (empty catalogue must still refuse)")
    else:
        print("  ok no_storable_models present")

    examined += 1
    run = method_body(text, "run") if text else None
    if not run:
        errors.append("GraphReplay missing run")
    elif "discovered[:ok]" not in run or "discovered[:reason]" not in run:
        errors.append("run does not forward discovery refusal (must check discovered[:ok] and discovered[:reason])")
    else:
        print("  ok run forwards discovery reason")

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("GRAPH REPLAY DISCOVERY FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("graph replay discovery: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
