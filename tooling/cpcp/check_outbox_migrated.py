#!/usr/bin/env python3
"""Fail if the host app does not install the gem outbox migration.

Gap 94. Lazy create_table is the out-of-band table: it exists in no
app migration and no schema.rb. Production install is a copy of
gems/vv-graph/db/migrate/20260811170000_create_vv_graph_projection_jobs.rb
into runtimes/mind-pod/app/db/migrate/. Contents must match.

Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

VERSION = "20260811170000"
NAME = "%s_create_vv_graph_projection_jobs.rb" % VERSION
GEM = Path("gems/vv-graph/db/migrate") / NAME
APP = Path("runtimes/mind-pod/app/db/migrate") / NAME


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

    gem_path = root / GEM
    examined += 1
    gem = gem_path.read_text(encoding="utf-8") if gem_path.is_file() else ""
    if not gem:
        errors.append("missing gem migration %s" % GEM.as_posix())
    else:
        print("  ok gem migration present")

    app_path = root / APP
    examined += 1
    app = app_path.read_text(encoding="utf-8") if app_path.is_file() else ""
    if not app:
        errors.append("missing app migration %s" % APP.as_posix())
    else:
        print("  ok app migration present")

    if gem and app and gem != app:
        errors.append("app migration diverges from gem copy")
    elif gem and app:
        print("  ok app migration matches gem")

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("OUTBOX MIGRATED FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("outbox migrated: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
