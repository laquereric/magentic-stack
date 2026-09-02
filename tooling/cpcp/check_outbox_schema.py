#!/usr/bin/env python3
"""Fail if outbox missing and schema-check-failed collapse to one boolean.

Gap 69. ensure_schema! used to return false for both. Immediate used
to call ensure_schema! as a silent success path and then drain anyway.
Production must refuse on each cause with its own reason, and must not
create_table at runtime.

Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

JOB = Path("gems/vv-graph/lib/vv/graph/projection_job.rb")
IMM = Path("gems/vv-graph/lib/vv/graph/publisher/immediate.rb")


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

    job_path = root / JOB
    examined += 1
    job = job_path.read_text(encoding="utf-8", errors="replace") if job_path.is_file() else ""
    if not job:
        errors.append("missing %s" % JOB.as_posix())

    examined += 1
    body = method_body(job, "schema_status") if job else None
    if not body:
        errors.append("ProjectionJob missing schema_status")
    elif ":missing" not in body or ":check_failed" not in body:
        errors.append("schema_status does not name :missing and :check_failed")
    else:
        print("  ok schema_status names :missing and :check_failed")

    examined += 1
    avail = method_body(job, "available?") if job else None
    if not avail or "schema_status" not in avail:
        errors.append("available? is not derived from schema_status")
    else:
        print("  ok available? derives from schema_status")

    imm_path = root / IMM
    examined += 1
    imm = imm_path.read_text(encoding="utf-8", errors="replace") if imm_path.is_file() else ""
    if not imm:
        errors.append("missing %s" % IMM.as_posix())

    examined += 1
    ready = method_body(imm, "outbox_status") or method_body(imm, "outbox_ready?") or ""
    if "ensure_schema!" in ready:
        errors.append("Immediate outbox_status/ready still calls ensure_schema! (lazy create)")
    else:
        print("  ok Immediate does not create_table via outbox_status")

    examined += 1
    sched = method_body(imm, "schedule") or ""
    if "ensure_schema!" in sched:
        errors.append("Immediate#schedule still calls ensure_schema!")
    if "refuse_undurable!" not in sched and "outbox_not_installed" not in sched:
        errors.append("Immediate#schedule does not refuse when outbox is undurable")
    else:
        print("  ok Immediate#schedule refuses when undurable")

    examined += 1
    if "outbox_not_installed" not in imm or "outbox_schema_check_failed" not in imm:
        errors.append("Immediate missing distinct refusal reasons")
    else:
        print("  ok distinct reasons outbox_not_installed / outbox_schema_check_failed")

    examined += 1
    refuse = method_body(imm, "refuse_undurable!") or ""
    for key in ("state_reached", "inconsistency", "restore_when", "restore_action"):
        if key not in refuse:
            errors.append("refuse_undurable! missing restoration key %s" % key)
    if refuse and all(k in refuse for k in ("state_reached", "inconsistency", "restore_when", "restore_action")):
        print("  ok refuse_undurable! is restoration-grade")

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("OUTBOX SCHEMA FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("outbox schema: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
