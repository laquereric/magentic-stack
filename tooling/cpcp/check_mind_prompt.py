#!/usr/bin/env python3
"""Fail if the MIND system prompt drifts or re-teaches what gap 62 removed.

The MindCognition class docstring IS the system prompt (NOOA
agent.py:437-452 walks the MRO). check_boundary.py skips docstring
lines on purpose; this file is the product, not an implementation
comment.

Forbidden strings are the FALSE / MISCLASSIFIED claims gap 62 took
out. Required strings are the TRUE claims it kept. The sha256 pin
makes any other edit loud.

Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

SRC = Path("runtimes/mind-pod/mind/mind_agent.py")
PIN = Path("tooling/cpcp/mind_prompt_pin.json")
CLASS_RE = re.compile(
    r'class MindCognition\b[^\n]*:\n(?:[ \t]*\n)*[ \t]+"""(.*?)"""',
    re.S,
)

# Substrings that must not return (gap 62 FALSE / MISCLASSIFIED).
FORBIDDEN = (
    "durable memory",
    "knowledge lives in an RDF",
    "Shared truth lives in the graph",
    "every session ever",
    "the sole writer",
    "SPARQL SELECT",
)

# Substrings that must remain (gap 62 TRUE).
REQUIRED = (
    "You do not issue SPARQL",
    "BACK and BACKJOB",
    "nondeterministic inference",
    "Propose; never assert",
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

    src = root / SRC
    examined += 1
    if not src.is_file():
        errors.append("missing %s" % SRC.as_posix())
        text = ""
    else:
        text = src.read_text(encoding="utf-8")
        print("  ok %s" % SRC.as_posix())

    examined += 1
    m = CLASS_RE.search(text)
    if not m:
        errors.append("%s has no MindCognition class docstring" % SRC.as_posix())
        doc = ""
    else:
        doc = m.group(1)
        print("  ok MindCognition docstring chars=%d" % len(doc))

    pin_path = root / PIN
    examined += 1
    if not pin_path.is_file():
        errors.append("missing %s" % PIN.as_posix())
        pin = {}
    else:
        pin = json.loads(pin_path.read_text(encoding="utf-8"))
        print("  ok %s" % PIN.as_posix())

    if doc:
        digest = hashlib.sha256(doc.encode("utf-8")).hexdigest()
        examined += 1
        if digest != pin.get("sha256"):
            errors.append(
                "MindCognition docstring sha256 %s != pin %s — re-audit before updating the pin"
                % (digest, pin.get("sha256"))
            )
        else:
            print("  ok sha256 %s" % digest)
        examined += 1
        if int(pin.get("chars") or 0) != len(doc):
            errors.append("chars %d != pin %s" % (len(doc), pin.get("chars")))
        else:
            print("  ok chars %d" % len(doc))

        folded = re.sub(r"\s+", " ", doc)
        for needle in FORBIDDEN:
            examined += 1
            if needle.lower() in folded.lower():
                errors.append("forbidden claim returned: %r" % needle)
            else:
                print("  ok absent %r" % needle)

        for needle in REQUIRED:
            examined += 1
            if needle not in folded:
                errors.append("required claim missing: %r" % needle)
            else:
                print("  ok present %r" % needle)

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("MIND PROMPT FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("mind prompt: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
