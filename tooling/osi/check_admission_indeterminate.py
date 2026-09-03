#!/usr/bin/env python3
"""Fail if any admission-path OperationRequest is indeterminate.

admitted    = authorized and not refused
refused     = refused (never response_refused)
not_an_admission = operation name on the declared list (today:
                   l8.execution.complete). POSITIVE property, not a fallback.
indeterminate = in the admission path, neither authorized nor refused.
               Required population: zero.

The pre-drop dump is a gate: every recorded database must show
indeterminate=0. Live sqlite files under CHECK_ROOT are classified the
same way if present. Empty CHECK_ROOT fails.
"""
from __future__ import annotations

import json
import os
import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

DUMP = "gems/rails-osi-level-8/db/dumps/0052-pre-drop.json"
NOT_AN_ADMISSION = ("l8.execution.complete",)


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


def classify_conn(con):
    tables = [r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type='table'")]
    if "osi_l8_operation_requests" not in tables:
        return None
    nots = ",".join(["?"] * len(NOT_AN_ADMISSION))
    params = list(NOT_AN_ADMISSION) * 4
    q = f"""
    SELECT COUNT(*) AS total,
      SUM(CASE WHEN r.operation_name IN ({nots}) THEN 1 ELSE 0 END) AS not_an_admission,
      SUM(CASE WHEN r.operation_name NOT IN ({nots}) AND EXISTS (
        SELECT 1 FROM osi_l8_operation_journal_entries j
        WHERE j.operation_request_cid = r.cid AND j.event_kind = 'refused'
      ) THEN 1 ELSE 0 END) AS refused,
      SUM(CASE WHEN r.operation_name NOT IN ({nots}) AND EXISTS (
        SELECT 1 FROM osi_l8_operation_journal_entries j
        WHERE j.operation_request_cid = r.cid AND j.event_kind = 'authorized'
      ) AND NOT EXISTS (
        SELECT 1 FROM osi_l8_operation_journal_entries j
        WHERE j.operation_request_cid = r.cid AND j.event_kind = 'refused'
      ) THEN 1 ELSE 0 END) AS admitted,
      SUM(CASE WHEN r.operation_name NOT IN ({nots})
        AND NOT EXISTS (SELECT 1 FROM osi_l8_operation_journal_entries j
          WHERE j.operation_request_cid=r.cid AND j.event_kind='authorized')
        AND NOT EXISTS (SELECT 1 FROM osi_l8_operation_journal_entries j
          WHERE j.operation_request_cid=r.cid AND j.event_kind='refused')
      THEN 1 ELSE 0 END) AS indeterminate
    FROM osi_l8_operation_requests r
    """
    row = con.execute(q, params).fetchone()
    keys = ("total", "not_an_admission", "refused", "admitted", "indeterminate")
    return dict(zip(keys, [int(x or 0) for x in row]))


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

    dump_path = root / DUMP
    if not dump_path.is_file():
        print("FAIL: dump missing: %s" % DUMP, file=sys.stderr)
        return 1
    try:
        dump = json.loads(dump_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        print("FAIL: dump unparseable: %s" % e, file=sys.stderr)
        return 1
    dbs = dump.get("databases") or {}
    ok_pop, _ = emit_population(len(dbs))
    if not ok_pop:
        return 1

    errors = []
    if dump.get("not_an_admission_names") != list(NOT_AN_ADMISSION):
        errors.append("dump not_an_admission_names != %s" % (NOT_AN_ADMISSION,))
    for name, rec in dbs.items():
        n = int((rec or {}).get("indeterminate") or 0)
        print("  dump %s indeterminate=%d admitted=%s refused=%s not_an_admission=%s" % (
            name, n, rec.get("admitted"), rec.get("refused"), rec.get("not_an_admission")))
        if n != 0:
            errors.append("%s indeterminate=%d (must be 0)" % (name, n))

    sqlite_files = []
    for p in root.rglob("*.sqlite3"):
        if ".git" in p.relative_to(root).parts:
            continue
        sqlite_files.append(p)
    print("  sqlite files under CHECK_ROOT: %d" % len(sqlite_files))
    for p in sqlite_files:
        try:
            con = sqlite3.connect("file:%s?mode=ro" % p, uri=True)
            rec = classify_conn(con)
        except sqlite3.Error as e:
            print("  skip %s (%s)" % (p.relative_to(root).as_posix(), e))
            continue
        if rec is None:
            continue
        rel = p.relative_to(root).as_posix()
        print("  sqlite %s %s" % (rel, rec))
        if rec["indeterminate"] != 0:
            errors.append("%s indeterminate=%d" % (rel, rec["indeterminate"]))

    if errors:
        print("INDETERMINATE FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("indeterminate population: OK (0)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
