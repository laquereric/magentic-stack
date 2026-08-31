#!/usr/bin/env python3
"""Fail if the ADR 0056 two-writer split is unstated, ungated, or WAL is still inherited.

Four consequences of one decision (gaps 76-79), source half:

  76. config/domain_writers.json names who writes what; the gate is installed;
      bin/backjob's only AR write is Reconciliation.
  77. database.yml declares pragmas.journal_mode: wal.
  78. bin/backjob routes SQLITE_BUSY through SqliteBusy, not the generic print.
  79. is a prose sweep — not this checker.

Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

APP = Path("runtimes/mind-pod/app")
WRITERS_JSON = APP / "config" / "domain_writers.json"
DATABASE_YML = APP / "config" / "database.yml"
INITIALIZER = APP / "config" / "initializers" / "domain_writers.rb"
DOMAIN_WRITERS_RB = APP / "app" / "lib" / "domain_writers.rb"
SQLITE_BUSY_RB = APP / "app" / "lib" / "sqlite_busy.rb"
BACKJOB = APP / "bin" / "backjob"

WRITE_CALL = re.compile(
    r"\b([A-Z][\w:]*)\.(create!|create\b|save!|save\b|update!|update\b|"
    r"destroy!|destroy\b|insert_all|update_all|delete_all|upsert|"
    r"find_or_create_by!?)"
)
BULK = re.compile(r"\b(insert_all|update_all|delete_all|upsert)\b")


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


def code_lines(text: str):
    for line in text.splitlines():
        stripped = line.split("#", 1)[0]
        yield stripped


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

    def need(rel: Path):
        nonlocal examined
        examined += 1
        p = root / rel
        if not p.is_file():
            errors.append("missing %s" % rel.as_posix())
            return None
        print("  ok %s" % rel.as_posix())
        return p.read_text(encoding="utf-8", errors="replace")

    raw_json = need(WRITERS_JSON)
    spec = None
    if raw_json is not None:
        examined += 1
        try:
            spec = json.loads(raw_json)
        except json.JSONDecodeError as e:
            errors.append("unparseable %s: %s" % (WRITERS_JSON.as_posix(), e))
            spec = None
        else:
            backjob = (spec.get("roles") or {}).get("backjob") or {}
            writes = list(backjob.get("writes") or [])
            if writes != ["Reconciliation"]:
                errors.append(
                    "backjob.writes must be exactly [Reconciliation], got %r" % writes
                )
            else:
                print("  ok backjob.writes = Reconciliation only")
            tables = list(backjob.get("tables") or [])
            examined += 1
            if "reconciliations" not in tables:
                errors.append("backjob.tables must include reconciliations")
            else:
                print("  ok backjob.tables includes reconciliations")
            back = (spec.get("roles") or {}).get("back") or {}
            examined += 1
            if back.get("writes") != "all_domain":
                errors.append("back.writes must be all_domain")
            else:
                print("  ok back.writes = all_domain")

    init = need(INITIALIZER)
    if init is not None:
        examined += 1
        if "DomainWriters.install!" not in init:
            errors.append("%s does not call DomainWriters.install!" % INITIALIZER.as_posix())
        else:
            print("  ok initializer installs the gate")

    dw = need(DOMAIN_WRITERS_RB)
    if dw is not None:
        for needle in ("def guard!", "def install!", "before_save", "sql.active_record"):
            examined += 1
            if needle not in dw:
                errors.append("%s missing %s" % (DOMAIN_WRITERS_RB.as_posix(), needle))
            else:
                print("  ok DomainWriters contains %s" % needle)

    sb = need(SQLITE_BUSY_RB)
    if sb is not None:
        for needle in ('REASON = "sqlite_busy"', "def busy?", "RefusalLog.record"):
            examined += 1
            if needle not in sb:
                errors.append("%s missing %s" % (SQLITE_BUSY_RB.as_posix(), needle))
            else:
                print("  ok SqliteBusy contains %s" % needle)

    yml = need(DATABASE_YML)
    if yml is not None:
        examined += 1
        if re.search(r"pragmas:\s*\n\s*journal_mode:\s*wal\b", yml):
            print("  ok database.yml declares pragmas.journal_mode: wal")
        else:
            errors.append("%s does not declare pragmas.journal_mode: wal" % DATABASE_YML.as_posix())

    bj = need(BACKJOB)
    if bj is not None:
        text_code = "\n".join(code_lines(bj))
        examined += 1
        if "SqliteBusy.busy?" not in text_code or "SqliteBusy.record!" not in text_code:
            errors.append("%s does not route SQLITE_BUSY through SqliteBusy" % BACKJOB.as_posix())
        else:
            print("  ok backjob routes SQLITE_BUSY through SqliteBusy")

        writes = []
        for line in code_lines(bj):
            if BULK.search(line):
                errors.append("%s uses a callback-bypassing bulk write: %s" % (
                    BACKJOB.as_posix(), line.strip()))
            for m in WRITE_CALL.finditer(line):
                writes.append((m.group(1), m.group(2)))
        examined += 1
        unexpected = [(m, meth) for (m, meth) in writes if m != "Reconciliation"]
        if unexpected:
            errors.append(
                "%s AR writes besides Reconciliation: %s"
                % (BACKJOB.as_posix(), unexpected)
            )
        elif not any(m == "Reconciliation" for m, _ in writes):
            errors.append("%s has no Reconciliation write (split ungrounded)" % BACKJOB.as_posix())
        else:
            print("  ok backjob AR writes: %s" % writes)

    ok_pop, _rec = emit_population(examined, skipped=0, skipped_reason="")
    if not ok_pop:
        return 1
    if errors:
        print("TWO WRITERS FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("two writers: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
