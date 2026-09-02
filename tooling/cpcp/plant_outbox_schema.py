#!/usr/bin/env python3
"""Plants for gap 69. Collapse the two causes, or lazy-create, must fail.
Restores files.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/cpcp/check_outbox_schema.py"
JOB = ROOT / "gems/vv-graph/lib/vv/graph/projection_job.rb"
IMM = ROOT / "gems/vv-graph/lib/vv/graph/publisher/immediate.rb"


def run(env=None):
    e = os.environ.copy()
    if env:
        e.update(env)
    return subprocess.run(
        [sys.executable, str(CHECKER)],
        cwd=str(ROOT),
        env=e,
        capture_output=True,
        text=True,
    )


def note(rows, name, passed, detail):
    rows.append((name, passed, detail))
    return passed


def main():
    rows = []
    ok = True
    r = run()
    ok = note(rows, "clean", r.returncode == 0, "exit %d" % r.returncode) and ok
    r = run({"CHECK_ROOT": ""})
    ok = note(rows, "empty-root", r.returncode != 0, "exit %d" % r.returncode) and ok

    orig = JOB.read_text(encoding="utf-8")
    try:
        planted = orig.replace("def schema_status\n", "def schema_status_removed\n", 1)
        if planted == orig:
            ok = note(rows, "drop-status-edit", False, "could not rename schema_status") and ok
        else:
            JOB.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "drop-schema_status-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        JOB.write_text(orig, encoding="utf-8")

    orig_imm = IMM.read_text(encoding="utf-8")
    try:
        planted = orig_imm.replace(
            "::Vv::Graph::ProjectionJob.schema_status",
            "::Vv::Graph::ProjectionJob.ensure_schema!",
            1,
        )
        if planted == orig_imm:
            ok = note(rows, "lazy-create-edit", False, "could not plant ensure_schema!") and ok
        else:
            IMM.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "lazy-create-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        IMM.write_text(orig_imm, encoding="utf-8")

    orig = JOB.read_text(encoding="utf-8")
    needle = "        connection.data_source_exists?(table_name) ? :available : :missing\n"
    planted_line = (
        "        return :check_failed unless ::ActiveRecord::Base.connected?\n"
        + needle
    )
    try:
        if needle not in orig:
            ok = note(rows, "connected-edit", False, "could not find connection lookup") and ok
        else:
            JOB.write_text(orig.replace(needle, planted_line, 1), encoding="utf-8")
            r = run()
            ok = note(rows, "connected?-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        JOB.write_text(orig, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant outbox-schema: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
