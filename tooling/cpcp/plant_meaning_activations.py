#!/usr/bin/env python3
"""Plants for check_meaning_activations. Proves the gate fails when it should.

MeaningActivations.md names five gates and each gets a plant that triggers
exactly it. A checker that has never been planted is not a gate; it is a
function nobody has watched refuse.

Restores every file it touches.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/cpcp/check_meaning_activations.py"
MIGRATION = ROOT / "runtimes/mind-pod/app/db/migrate/20260911000001_create_meaning_activations.rb"
FRAME = ROOT / "runtimes/mind-pod/app/app/models/context_frame.rb"
WEIGHT = ROOT / "runtimes/mind-pod/app/app/models/context_frame_meaning_weight.rb"


def run():
    env = os.environ.copy()
    env.pop("CHECK_ROOT", None)
    return subprocess.run([sys.executable, str(CHECKER)], cwd=str(ROOT), env=env,
                          capture_output=True, text=True, timeout=300)


def plant(rows, name, path, mutate, marker):
    orig = path.read_text(encoding="utf-8")
    try:
        planted = mutate(orig)
        if planted == orig:
            rows.append((name, False, "could not plant"))
            return False
        path.write_text(planted, encoding="utf-8")
        r = run()
        caught = r.returncode != 0 and marker in (r.stdout + r.stderr)
        rows.append((name, caught, "exit %d" % r.returncode))
        return caught
    finally:
        path.write_text(orig, encoding="utf-8")


def main() -> int:
    rows: list[tuple[str, bool, str]] = []
    ok = True

    r = run()
    rows.append(("clean", r.returncode == 0, "exit %d" % r.returncode))
    ok = (r.returncode == 0) and ok

    # The parent FK the whole design exists to avoid.
    ok = plant(rows, "parent-fk-on-meanings", MIGRATION,
               lambda t: t.replace("    create_table :clarifications do |t|",
                                   "    add_column :meanings, :context_frame_id, :integer\n"
                                   "    create_table :clarifications do |t|"),
               "meanings.context_frame_id") and ok

    # The shortcut that would let a clarification inhibit under a frame its
    # meaning does not activate.
    ok = plant(rows, "shortcut-fk-on-clarifications", MIGRATION,
               lambda t: t.replace("    create_table :context_frame_meaning_weights do |t|",
                                   "    add_column :clarifications, :context_frame_id, :integer\n"
                                   "    create_table :context_frame_meaning_weights do |t|"),
               "clarifications.context_frame_id") and ok

    # A bound that lives only in the model is bypassed by update_column.
    ok = plant(rows, "range-model-only", MIGRATION,
               lambda t: t.replace("weight_out_of_range", "weight_looks_fine"),
               "database-level weight bound") and ok

    # Two weights for one pair, averaged instead of refused.
    ok = plant(rows, "pair-not-unique", MIGRATION,
               lambda t: t.replace("index_cfmw_on_frame_and_meaning", "index_cfmw_nonunique"),
               "index_cfmw_on_frame_and_meaning") and ok

    # The walk quietly including inhibitions and inert pairs.
    ok = plant(rows, "walk-includes-nonpositive", FRAME,
               lambda t: t.replace('.where("weight > 0")', '.where("weight >= -1")'),
               "positive weights") and ok

    # A refusal that stops naming itself is a refusal nobody can act on.
    ok = plant(rows, "unnamed-refusal", WEIGHT,
               lambda t: t.replace('message: "activation_not_unique",', ""),
               "duplicate pair by name") and ok

    r = run()
    rows.append(("restored", r.returncode == 0, "exit %d" % r.returncode))
    ok = (r.returncode == 0) and ok

    for name, passed, detail in rows:
        print("  %s %s -- %s" % ("ok" if passed else "FAIL", name, detail))
    print("population: %d examined, 0 skipped" % len(rows))
    print("plant meaning-activations: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
