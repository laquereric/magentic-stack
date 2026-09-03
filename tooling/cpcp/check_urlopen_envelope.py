#!/usr/bin/env python3
"""Fail if a Python caller can reach a non-200 without reading the body.

Gap 104. urllib.request.urlopen raises HTTPError on 4xx/5xx; the envelope
lives on e.read(). A bare with-urlopen never sees it.

Copy the in-tree pattern (mind_boundary_test.py, session_cycle_test.py):
except HTTPError as e, then e.read(). Do not catch URLError in the same
handler -- HTTPError is a URLError subclass; collapsing them is the
failure_layer mix gap 109 froze (infrastructure vs far-side decision).

Census: .py under gems/ and runtimes/, not upstreams/, not tooling/.
Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

SKIP_DIR = frozenset({
    ".git", "vendor", "node_modules", ".bundle", "__pycache__", "tmp", "log",
    "upstreams", ".venv", "venv", ".mm_tmp",
})
AREAS = ("gems", "runtimes")
URLOPEN = re.compile(r"\burlopen\s*\(")
HTTP_ERR = re.compile(r"urllib\.error\.HTTPError|\bHTTPError\b")
URL_ERR = re.compile(r"urllib\.error\.URLError|\bURLError\b")
READ_BODY = re.compile(r"\be\.read\s*\(")


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


def code_only(text: str) -> str:
    return "\n".join(line.split("#", 1)[0] for line in text.splitlines())


def defs(code: str):
    """Split on top-level def so each urlopen is judged with its handler."""
    parts = re.split(r"(?m)^(?:async\s+)?def\s+", code)
    # preamble (imports) may also contain urlopen; keep it as a chunk
    out = []
    if parts:
        out.append(("__preamble__", parts[0]))
        for chunk in parts[1:]:
            name = chunk.split("(", 1)[0].strip() or "(unnamed)"
            out.append((name, chunk))
    return out


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
    files = []
    for area in AREAS:
        base = root / area
        if not base.is_dir():
            continue
        for p in base.rglob("*.py"):
            try:
                rel_parts = p.relative_to(root).parts
            except ValueError:
                continue
            if any(part in SKIP_DIR for part in rel_parts):
                continue
            files.append(p)

    for p in sorted(files):
        rel = p.relative_to(root).as_posix()
        src = p.read_text(encoding="utf-8", errors="replace")
        code = code_only(src)
        if not URLOPEN.search(code):
            continue
        for name, chunk in defs(code):
            n = len(URLOPEN.findall(chunk))
            if n == 0:
                continue
            examined += n
            label = "%s def %s" % (rel, name)
            if not HTTP_ERR.search(chunk):
                errors.append("%s: urlopen with no HTTPError handler" % label)
                continue
            if not READ_BODY.search(chunk):
                errors.append("%s: HTTPError handler does not e.read() the body" % label)
            # URLError except that is not HTTPError-specific collapses the layers.
            for m in re.finditer(r"except\s+\(?([^):]+)\)?", chunk):
                clause = m.group(1)
                if URL_ERR.search(clause) and not HTTP_ERR.search(clause):
                    errors.append(
                        "%s: except URLError catches HTTPError (subclass); "
                        "do not collapse infrastructure and refusal" % label
                    )
            print("  ok %s (%d urlopen)" % (label, n))

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("URLOPEN ENVELOPE FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("urlopen envelope: OK (%d urlopen sites)" % examined)
    return 0


if __name__ == "__main__":
    sys.exit(main())
