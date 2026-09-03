#!/usr/bin/env python3
"""Fail if a Withdrawn-list quote is unmarked at its origin.

Row 115. Any sentence quoted in an amendment's Withdrawn list must be
struck (~~ ~~) at the source line with a pointer containing 'withdrawn'.
A quote that cannot be found outside the list is unmatched -- FAIL, not
a silent pass. Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

ADR_DIR = Path("docs/adr")
MIN_QUOTE = 16
WITHDRAWN_RE = re.compile(
    r"(?is)\*\*Withdrawn[^*]*:\*\*(.*?)(?=\n\*\*Now:\*\*|\n#{1,3} |\Z)"
)
QUOTE_RE = re.compile(r'"([^"]{%d,})"' % MIN_QUOTE, re.S)
AMEND_HEAD_RE = re.compile(r"(?im)^#{1,3} +Amendment\b")


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


def norm(s: str) -> str:
    s = s.replace("`", "").replace("*", "").replace("_", "")
    s = re.sub(r"\s+", " ", s)
    return s.strip()


def strike_spans(text: str):
    marks = [m.start() for m in re.finditer(r"~~", text)]
    out = []
    for i in range(0, len(marks) - 1, 2):
        out.append((marks[i], marks[i + 1] + 2))
    return out


def inside(spans, start, end):
    for a, b in spans:
        if a <= start and end <= b:
            return True
    return False


def pointer_after(text: str, end: int) -> bool:
    rest = text[end:end + 240]
    cut = rest.find("\n\n")
    if cut != -1:
        rest = rest[:cut]
    return bool(re.search(r"\bwithdrawn\b", rest, re.I))


def extract_quotes(block: str):
    found = []
    for m in QUOTE_RE.finditer(block):
        q = norm(m.group(1))
        if len(q) >= MIN_QUOTE:
            found.append(q)
    return found


def find_in_text(haystack: str, needle: str):
    parts = []
    for p in needle.split():
        p = p.strip(".,:;!")
        if p:
            parts.append(re.escape(p))
    if not parts:
        return []
    # Origin lines carry strike/bold/blockquote markup between words.
    sep = r"(?:[\s*`~_>#\[\]().,:;!]+)"
    rx = re.compile(sep.join(parts), re.S)
    return [(m.start(), m.end()) for m in rx.finditer(haystack)]


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
    adr_dir = root / ADR_DIR
    if not adr_dir.is_dir():
        print("FAIL: missing %s" % ADR_DIR.as_posix(), file=sys.stderr)
        emit_population(0)
        return 1

    files = sorted(p for p in adr_dir.glob("*.md") if p.name != "README.md")
    amended = 0
    quotes_n = 0
    for path in files:
        text = path.read_text(encoding="utf-8", errors="replace")
        rel = path.relative_to(root).as_posix()
        is_amended = bool(AMEND_HEAD_RE.search(text))
        blocks = list(WITHDRAWN_RE.finditer(text))
        if not is_amended and not blocks:
            continue
        examined += 1
        amended += 1
        if not blocks:
            print("  ok %s (amendment, 0 withdrawn quotes)" % rel)
            continue
        strikes = strike_spans(text)
        withdrawn_spans = [(m.start(), m.end()) for m in blocks]
        for bm in blocks:
            quotes = extract_quotes(bm.group(1))
            if not quotes:
                errors.append("%s Withdrawn list has no quoted sentence (>=%d chars)" % (rel, MIN_QUOTE))
                continue
            for q in quotes:
                quotes_n += 1
                examined += 1
                hits = find_in_text(text, q)
                origin_marked = []
                origin_bare = []
                in_list_only = True
                for start, end in hits:
                    if inside(withdrawn_spans, start, end):
                        continue
                    in_list_only = False
                    if inside(strikes, start, end) and pointer_after(text, end):
                        origin_marked.append((start, end))
                    else:
                        origin_bare.append((start, end))
                if in_list_only or not hits:
                    errors.append("%s unmatched withdrawn quote: %r" % (rel, q[:80]))
                elif origin_bare and not origin_marked:
                    errors.append("%s origin unmarked for: %r" % (rel, q[:80]))
                elif origin_marked:
                    print("  ok %s struck %r" % (rel, q[:60]))
                else:
                    errors.append("%s withdrawn quote not struck with pointer: %r" % (rel, q[:80]))

    populated, pop = emit_population(examined)
    if not populated:
        return 1
    if errors:
        for e in errors:
            print("FAIL: %s" % e, file=sys.stderr)
        print(json.dumps({"gate": "withdrawn-quotes", "status": "fail", "population": pop, "errors": errors}, indent=2))
        return 1
    print("OK withdrawn-quotes (%d examined, %d amended ADRs, %d quotes)" % (examined, amended, quotes_n))
    return 0


if __name__ == "__main__":
    sys.exit(main())
