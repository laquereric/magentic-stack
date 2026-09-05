#!/usr/bin/env python3
"""Hold the two refusal registers apart (ADR 0064).

A request turned away at the shape gate never becomes an OperationRequest, so it
can take no journal row; it is an AdmissionAttempt. A request that WAS admitted
and whose answer we then refused is a different event with a different culprit.
ADR 0052 already says why this matters: "response_refused is not refused. One is
a refused response, the other a refused admission. Conflating them would
reintroduce the same class of error this ADR exists to remove."

Three rules, each of which has been violated in this tree:

  1. refusal_reason is not derived from conforms. It was
     `refusal_reason: conforms ? nil : reason`, which makes the reason a
     restatement of the boolean instead of an independent fact.
  2. No write pairs conforms:false with response_refused. The request conformed;
     the answer did not. Recording it as a non-conforming request files our bug
     as the caller's, in the one table whose job is to say which it was.
  3. Refusal evidence stays private_local. A refused payload never passed its
     shape, so it is unvalidated caller-controlled input; publishing it
     canonically would make refusal an injection route into shared evidence.

Empty CHECK_ROOT fails.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

SCAN_PREFIXES = ("gems/", "runtimes/")
SKIP_DIR = {".git", "vendor", "node_modules", "tmp"}

# refusal_reason whose value mentions conforms at all.
REASON_FROM_CONFORMS = re.compile(r"refusal_reason:\s*[^,\n]*\bconforms\b")
RESPONSE_REFUSED = re.compile(r"response_refused")
CONFORMS_FALSE = re.compile(r"conforms:\s*false")
ADMISSION_CREATE = re.compile(r"AdmissionAttempt\.create!")
PRIVATE_LOCAL = re.compile(r'ledger_placement:\s*"private_local"')

# This file quotes the forbidden patterns in order to search for them.
ALLOW_REL = ("tooling/osi/check_refusal_registers.py",)

# How far a create! call's keyword arguments may run.
CALL_WINDOW = 30
# A conforms:/reason: pair belongs to one call; they sit within a few lines.
PAIR_WINDOW = 4


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


def code_line(line: str) -> str:
    """The executable part. A rule quoted in a comment is documentation."""
    return line.split("#", 1)[0]


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
    for p in root.rglob("*.rb"):
        if not p.is_file():
            continue
        rel_parts = p.relative_to(root).parts
        if any(part in SKIP_DIR for part in rel_parts):
            continue
        rel = p.relative_to(root).as_posix()
        if not any(rel.startswith(pre) for pre in SCAN_PREFIXES):
            continue
        files.append(p)

    ok_pop, _ = emit_population(len(files))
    if not ok_pop:
        return 1

    errors = []
    for p in files:
        rel = p.relative_to(root).as_posix()
        if rel in ALLOW_REL:
            continue
        lines = p.read_text(encoding="utf-8", errors="replace").splitlines()
        code = [code_line(l) for l in lines]

        for i, line in enumerate(code):
            # 1. the reason must be its own fact
            if REASON_FROM_CONFORMS.search(line):
                errors.append(
                    "%s:%d refusal_reason derived from conforms -- the reason is a "
                    "separate fact, not a restatement of the boolean: %s"
                    % (rel, i + 1, lines[i].strip())
                )

            # 2. a response refusal must not be filed as a bad request
            if RESPONSE_REFUSED.search(line):
                lo = max(0, i - PAIR_WINDOW)
                window = code[lo:i + PAIR_WINDOW + 1]
                if any(CONFORMS_FALSE.search(w) for w in window):
                    errors.append(
                        "%s:%d response_refused recorded with conforms:false -- the "
                        "request conformed; the ANSWER did not, and the evidence "
                        "must not blame the caller (ADR 0052, ADR 0064): %s"
                        % (rel, i + 1, lines[i].strip())
                    )

            # 3. refusal evidence does not cross the boundary
            if ADMISSION_CREATE.search(line):
                window = code[i:i + CALL_WINDOW]
                if not any(PRIVATE_LOCAL.search(w) for w in window):
                    errors.append(
                        "%s:%d AdmissionAttempt.create! without "
                        'ledger_placement: "private_local" -- a refused payload is '
                        "unvalidated caller-controlled input and must not be "
                        "published into shared evidence" % (rel, i + 1)
                    )

    if errors:
        print("REFUSAL REGISTERS FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("refusal registers held apart: OK (%d ruby files)" % len(files))
    return 0


if __name__ == "__main__":
    sys.exit(main())
