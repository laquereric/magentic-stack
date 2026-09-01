#!/usr/bin/env python3
"""Fail if SUBJECT_KINDS dropped topology/doctrine/data, or the ingest
gate is unstated.

Gap 92. Those three kinds are in the closed vocabulary because twelve
accepted ADRs are about them. Reclassifying them as repo would hide
the question the vocabulary exists to answer.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

VOCAB = Path("gems/mmg-adr/lib/mmg/adr/vocabulary.rb")
WORKFLOW = Path(".github/workflows/adr-ingest.yml")
REQUIRED = ("topology", "doctrine", "data")


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

    vocab = root / VOCAB
    examined += 1
    if not vocab.is_file():
        errors.append("missing %s" % VOCAB.as_posix())
        text = ""
    else:
        text = vocab.read_text(encoding="utf-8", errors="replace")
        print("  ok %s" % VOCAB.as_posix())

    m = re.search(r"SUBJECT_KINDS\s*=\s*%w\[(.*?)\]", text, re.S)
    examined += 1
    kinds = m.group(1).split() if m else []
    if not m:
        errors.append("%s has no SUBJECT_KINDS" % VOCAB.as_posix())
    else:
        print("  ok SUBJECT_KINDS = %s" % kinds)
        for k in REQUIRED:
            examined += 1
            if k in kinds:
                print("  ok kind %s" % k)
            else:
                errors.append("SUBJECT_KINDS missing %s" % k)

    wf = root / WORKFLOW
    examined += 1
    if not wf.is_file():
        errors.append("missing %s" % WORKFLOW.as_posix())
    else:
        body = wf.read_text(encoding="utf-8", errors="replace")
        print("  ok %s" % WORKFLOW.as_posix())
        examined += 1
        if "bundle exec rspec" in body and "mmg-adr" in body:
            print("  ok adr-ingest workflow runs the mmg-adr suite")
        else:
            errors.append("%s does not run the mmg-adr suite" % WORKFLOW.as_posix())

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("ADR KINDS FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("adr kinds: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
