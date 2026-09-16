#!/usr/bin/env python3
"""Plants for check_no_story_tables_in_mind_pod. Proves the gate fails when it should."""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/boundary/check_no_story_tables_in_mind_pod.py"
SCHEMA = ROOT / "runtimes/mind-pod/app/db/schema.rb"
MIG = ROOT / "runtimes/mind-pod/app/db/migrate/20990101000000_create_story_nodes.rb"


def run():
    env = os.environ.copy()
    env.pop("CHECK_ROOT", None)
    return subprocess.run(
        [sys.executable, str(CHECKER)], cwd=str(ROOT), env=env,
        capture_output=True, text=True, timeout=120,
    )


def plant_file(rows, name, path, mutate):
    orig = path.read_text(encoding="utf-8")
    try:
        planted = mutate(orig)
        if planted == orig:
            rows.append((name, False, "could not plant -- the text it targets is gone"))
            return False
        path.write_text(planted, encoding="utf-8")
        r = run()
        rows.append((name, r.returncode != 0, "exit %d" % r.returncode))
        return r.returncode != 0
    finally:
        path.write_text(orig, encoding="utf-8")


def main() -> int:
    rows: list[tuple[str, bool, str]] = []
    ok = True

    r = run()
    rows.append(("clean", r.returncode == 0, "exit %d" % r.returncode))
    ok = (r.returncode == 0) and ok

    ok = plant_file(
        rows, "schema-grows-story-nodes", SCHEMA,
        lambda t: t.replace(
            '  create_table "actors", force: :cascade do |t|',
            '  create_table "story_nodes", force: :cascade do |t|\n'
            '    t.text "s"\n'
            "  end\n\n"
            '  create_table "actors", force: :cascade do |t|',
        ),
    ) and ok

    existed = MIG.exists()
    try:
        MIG.write_text(
            "class CreateStoryNodes < ActiveRecord::Migration[8.0]\n"
            "  def change\n"
            '    create_table :story_nodes do |t|\n'
            "      t.text :s\n"
            "    end\n"
            "  end\n"
            "end\n",
            encoding="utf-8",
        )
        r = run()
        rows.append(("migration-grows-story-nodes", r.returncode != 0, "exit %d" % r.returncode))
        ok = (r.returncode != 0) and ok
    finally:
        if not existed:
            MIG.unlink(missing_ok=True)

    r = run()
    rows.append(("restored", r.returncode == 0, "exit %d" % r.returncode))
    ok = (r.returncode == 0) and ok

    print("plant_no_story_tables_in_mind_pod:")
    for name, passed, detail in rows:
        print("  %s  %s  %s" % ("ok" if passed else "FAIL", name, detail))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
