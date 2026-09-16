#!/usr/bin/env python3
"""Plants for check_perch_schema. Proves the gate fails when it should."""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/perch/check_perch_schema.py"
MIG = ROOT / "gems/vv-perch/db/migrate/20260915000000_create_vv_perch.rb"
SLICE = ROOT / "gems/vv-perch/lib/vv/perch/slice.rb"
REFUSALS = ROOT / "gems/vv-perch/lib/vv/perch/refusals.rb"
DOCTRINE = ROOT / "gems/vv-perch/lib/vv/perch/doctrine.rb"
PERCH_RB = ROOT / "gems/vv-perch/lib/vv/perch.rb"
SEAM = ROOT / "runtimes/mind-pod/app/lib/perch_seam.rb"
SIGNAL = ROOT / "gems/vv-perch/lib/vv/perch/outward_signal.rb"
FREEZE = ROOT / "gems/vv-perch/lib/vv/perch/freeze.rb"
FEDGE = ROOT / "gems/vv-perch/lib/vv/perch/freeze_edge.rb"


def run():
    env = os.environ.copy()
    env.pop("CHECK_ROOT", None)
    return subprocess.run(
        [sys.executable, str(CHECKER)], cwd=str(ROOT), env=env,
        capture_output=True, text=True, timeout=120
    )


def plant(rows, name, path, mutate):
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

    ok = plant(rows, "jws-column", MIG,
               lambda t: t.replace("t.string :effect_ref, null: false",
                                   "t.string :effect_ref, null: false\n      t.string :jws")) and ok

    ok = plant(rows, "priority-column", MIG,
               lambda t: t.replace("t.boolean :rank_together, null: false, default: false",
                                   "t.integer :priority")) and ok

    ok = plant(rows, "methods-released-boolean", MIG,
               lambda t: t.replace("t.string :prod_binding_ref",
                                   "t.boolean :released, default: false\n      t.string :prod_binding_ref")) and ok

    ok = plant(rows, "effect-executor", MIG,
               lambda t: t.replace("t.string :mode, null: false",
                                   "t.string :mode, null: false\n      t.string :executor")) and ok

    ok = plant(rows, "released-at-on-slice", SLICE,
               lambda t: t.replace("def pass_gate!",
                                   "def stamp_release!; self.released_at = Time.now.utc; end\n      def pass_gate!")) and ok

    ok = plant(rows, "t5-unnamed", REFUSALS,
               lambda t: t.replace('T5 = "slices_are_one_whole"', 'T5_MISSING = "slices_are_one_whole"')) and ok

    ok = plant(rows, "nooa-required", PERCH_RB,
               lambda t: t.replace('require_relative "perch/doctrine"',
                                   'require_relative "perch/doctrine"\nrequire "nooa"')) and ok

    ok = plant(rows, "o4-default-not-canonical", DOCTRINE,
               lambda t: t.replace('DEFAULT_PLACEMENT = "canonical"',
                                   'DEFAULT_PLACEMENT = "private_local"')) and ok

    ok = plant(rows, "seam-drops-actor-binding", SEAM,
               lambda t: t.replace("ActorBinding", "OtherBinding")) and ok

    # STAGE 2. The inverted rule, reproduced: drop the class filter and a
    # matured INWARD verdict finishes the slice.
    ok = plant(rows, "signal-drops-outward-filter", SIGNAL,
               lambda t: t.replace('readings.where(signal_class: "outward")',
                                   "readings")) and ok

    # The window stops being read, so pending means "unstamped" again.
    # The window stops being COMPUTED -- the field is still mentioned all over
    # the file, which is why "is delay_iso8601 present?" was too weak a rule.
    ok = plant(rows, "signal-ignores-the-delay", SIGNAL,
               lambda t: t.replace("reading.observed_at + secs.to_i",
                                   "reading.observed_at")) and ok

    # A state that stops being named cannot be branched on.
    ok = plant(rows, "signal-loses-a-state", SIGNAL,
               lambda t: t.replace(":not_instrumented if instrumented_at.nil?",
                                   ":pending if instrumented_at.nil?")) and ok

    # STAGE 3. The cascade set comes back but nothing is priced -- F5 as a memo.
    ok = plant(rows, "freeze-prices-nothing", FREEZE,
               lambda t: t.replace("def self.price(freeze)", "def self.priced_out(freeze)")) and ok

    # The record of what the climber was shown loses its writer again.
    ok = plant(rows, "climb-stops-recording-what-was-shown", FREEZE,
               lambda t: t.replace("cost_shown_at_climb: JSON.generate(shown),", "")) and ok

    # A magnitude this gem cannot derive, reported as if it could.
    ok = plant(rows, "freeze-invents-gpu-hours", FREEZE,
               lambda t: t.replace('"affected" => affected.length,',
                                   '"affected" => affected.length,\n          "gpu_hours" => 180,')) and ok

    # The cycle guard goes, and a loop then prices wrongly in silence.
    ok = plant(rows, "freeze-edges-allow-a-cycle", FEDGE,
               lambda t: t.replace("Freeze.cascade_from(rung_freeze)", "[]")) and ok

    print("plant_perch_schema:")
    for name, passed, detail in rows:
        mark = "ok" if passed else "FAIL"
        print("  %s  %s  %s" % (mark, name, detail))
        if not passed:
            ok = False
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
