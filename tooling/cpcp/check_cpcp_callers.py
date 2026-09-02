#!/usr/bin/env python3
"""Fail if a new _cpcp/rpc site is unclassified, or the census is stale.

Gap 59. Envelope changes need a caller analysis. The analysis is this
inventory: every code file that contains the token _cpcp/rpc is kind
caller | server | config | tooling. A new HTTP client of BACK that is
not listed is a silent extra language.

Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

INVENTORY = Path("tooling/cpcp/cpcp_callers.json")
KINDS = ("caller", "server", "config", "tooling")
CODE_EXT = {".py", ".js", ".mjs", ".rb"}
SKIP_DIR = frozenset({
    ".git", "vendor", "node_modules", ".bundle", "__pycache__", "tmp", "log",
    "tooling",
})
TOKEN = "_cpcp/rpc"


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
    return path.suffix in CODE_EXT or path.name == "backjob"


def live_files(root: Path):
    out = []
    for p in root.rglob("*"):
        if not p.is_file() or not is_code(p):
            continue
        try:
            rel_parts = p.relative_to(root).parts
        except ValueError:
            continue
        if any(part in SKIP_DIR for part in rel_parts):
            continue
        rel = "/".join(rel_parts)
        text = p.read_text(encoding="utf-8", errors="replace")
        if TOKEN in text:
            out.append(rel)
    return sorted(out)


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
    inv_path = root / INVENTORY
    if not inv_path.is_file():
        print("FAIL: missing %s" % INVENTORY.as_posix(), file=sys.stderr)
        emit_population(0)
        return 1
    doc = json.loads(inv_path.read_text(encoding="utf-8"))
    entries = doc.get("entries") or []
    listed = {}
    for row in entries:
        kind = row.get("kind")
        rel = row.get("file")
        if kind not in KINDS:
            errors.append("inventory %s has kind %r not in %s" % (rel, kind, KINDS))
        if not rel:
            errors.append("inventory row missing file")
            continue
        listed[rel] = row
        if not (root / rel).is_file():
            errors.append("inventory names missing file %s" % rel)

    live = live_files(root)
    for rel in live:
        if rel not in listed:
            errors.append("UNCLASSIFIED _cpcp/rpc site: %s" % rel)
        else:
            print("  ok %s kind=%s" % (rel, listed[rel].get("kind")))
    for rel in sorted(set(listed) - set(live)):
        errors.append("inventory names %s but it has no _cpcp/rpc token" % rel)

    callers = [r for r in entries if r.get("kind") == "caller"]
    servers = [r for r in entries if r.get("kind") == "server"]
    print("  callers %d servers %d config %d tooling %d" % (
        len(callers), len(servers),
        sum(1 for r in entries if r.get("kind") == "config"),
        sum(1 for r in entries if r.get("kind") == "tooling"),
    ))
    py_callers = [r["file"] for r in callers if r.get("lang") == "python"]
    js_callers = [r["file"] for r in callers if r.get("lang") == "javascript"]
    print("  python callers of BACK: %d %s" % (len(py_callers), py_callers))
    print("  javascript callers of BACK: %d %s" % (len(js_callers), js_callers))

    examined = len(live) + len(listed)
    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("CPCP CALLERS FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors[:40]:
            print("  " + e, file=sys.stderr)
        return 1
    print("cpcp callers: OK (%d live files, %d inventory)" % (len(live), len(listed)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
