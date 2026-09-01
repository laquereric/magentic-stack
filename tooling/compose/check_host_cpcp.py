#!/usr/bin/env python3
"""Fail if host-facing docs teach FRONT :13000 as the CPCP seam, or if
make demo names a compose overlay that does not exist.

Gap 61. :13000 is the FRONT web page. FRONT is route-gated off /_cpcp.
Host CPCP is BACK (extract :13002, make demo / CI overlay :3000).
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

HOST_FILES = (
    "Makefile",
    "QUICKSTART.md",
    "README.md",
    "bootstrap",
    "bin/docker-containers",
    ".threedot/cid.json",
    "runtimes/mind-pod/README.md",
    "runtimes/mind-pod/app/extract/compose.yml",
)
FORBIDDEN = re.compile(r"localhost:13000/_cpcp")
BACKURL_13000 = re.compile(r'"backUrl"\s*:\s*"http://localhost:13000"')
MAKEFILE = Path("Makefile")
OVERLAY_RE = re.compile(r"docker compose -f docker-compose.yml -f (\S+)")


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

    for rel in HOST_FILES:
        examined += 1
        path = root / rel
        if not path.is_file():
            errors.append("missing %s" % rel)
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        print("  ok %s" % rel)
        if FORBIDDEN.search(text):
            errors.append("%s teaches localhost:13000/_cpcp (FRONT, 404)" % rel)
        if BACKURL_13000.search(text):
            errors.append("%s backUrl still points at FRONT :13000" % rel)

    examined += 1
    mk = root / MAKEFILE
    if not mk.is_file():
        errors.append("missing Makefile")
    else:
        mk_text = mk.read_text(encoding="utf-8", errors="replace")
        overlays = OVERLAY_RE.findall(mk_text)
        if not overlays:
            errors.append("Makefile demo names no compose overlay")
        for rel in overlays:
            examined += 1
            overlay = root / "runtimes/mind-pod" / rel
            if overlay.is_file():
                print("  ok overlay %s" % rel)
            else:
                errors.append("Makefile overlay missing: %s" % rel)

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("HOST CPCP FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("host cpcp: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
