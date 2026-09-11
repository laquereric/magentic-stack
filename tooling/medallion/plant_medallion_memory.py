#!/usr/bin/env python3
"""Plants for check_medallion_memory. Proves the gate fails when it should.

The plants that matter most here put back the two failures the plan spends the
most words on:

  platinum-becomes-a-tier   a fourth Build rank, which is the maximalism audit!
                            exists to reject and which breaks the one guarantee
                            the medallion has: that a fact can be deleted
  conformer-forked-in       a private Conformer in this gem, which is the fork
                            the plan names as a non-goal and which the next Flow
                            would fork again

Restores every file it touches.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/medallion/check_medallion_memory.py"
LIB = ROOT / "gems/vv-medallion_memory/lib/vv/medallion_memory"
TIER = LIB / "tier.rb"
REFUSAL = LIB / "refusal.rb"
FLOW = LIB / "flow.rb"
BINDING = LIB / "engine_binding.rb"
PROVENANCE = LIB / "provenance.rb"
FORK_PROBE = LIB / "_plant_conformer.rb"
PLAN = ROOT / "docs/architecture/plan_vv_medallion_memory.md"


def run():
    env = os.environ.copy()
    env.pop("CHECK_ROOT", None)
    return subprocess.run([sys.executable, str(CHECKER)], cwd=str(ROOT), env=env,
                          capture_output=True, text=True, timeout=900)


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

    # A FOURTH BUILD TIER.
    ok = plant(rows, "platinum-becomes-a-tier", TIER,
               lambda t: t.replace(
                   '        { slug: "gold", rank: 3,',
                   '        { slug: "platinum", rank: 4, memory: "weights",\n'
                   '          guarantees: "none" },\n'
                   '        { slug: "gold", rank: 3,')) and ok

    # The refusal stops explaining itself, so the next person reads it as an
    # oversight.
    ok = plant(rows, "platinum-refusal-loses-its-reason", TIER,
               lambda t: t.replace("has no tombstone", "is not supported")) and ok

    # THE FORK. A private Conformer in this gem.
    orig_probe_existed = FORK_PROBE.exists()
    try:
        FORK_PROBE.write_text(
            "module Vv\n  module MedallionMemory\n    class Conformer\n"
            "      def call(*) = :planted\n    end\n  end\nend\n",
            encoding="utf-8",
        )
        r = run()
        rows.append(("conformer-forked-in", r.returncode != 0, "exit %d" % r.returncode))
        ok = (r.returncode != 0) and ok
    finally:
        if not orig_probe_existed:
            FORK_PROBE.unlink(missing_ok=True)

    # The blocker becomes a comment again.
    ok = plant(rows, "blocker-stops-refusing", BINDING,
               lambda t: t.replace("MEDALLION_HOME_UNDECIDED", "SOME_OTHER_THING")) and ok

    # The refusal can no longer say what it is waiting for.
    ok = plant(rows, "blocker-forgets-what-it-waits-for", BINDING,
               lambda t: t.replace('"M7" => "purpose carried on Flow/Tier",\n', "")) and ok

    # A refusal disappears before the happy path is claimed.
    ok = plant(rows, "refusal-vocabulary-shrinks", REFUSAL,
               lambda t: t.replace('BRONZE_MUTATED = "bronze_mutated"',
                                   'BRONZE_MUTATED = "oops"')) and ok

    # memory.distill unblocked while a tombstone still cannot cascade.
    ok = plant(rows, "distill-unblocked", FLOW,
               lambda t: t.replace("blocked_by: %w[M5-temporal-validity M9-deletion-cascades]",
                                   "blocked_by: []")) and ok

    # The cardinal sin permitted: derived text lands wearing an observed stamp.
    ok = plant(rows, "summary-lands-as-observed", PROVENANCE,
               lambda t: t.replace("if observed? && present?(derived_from)",
                                   "if false && present?(derived_from)")) and ok

    # The generation counter unbounded, so a reflection may derive from a
    # reflection forever.
    ok = plant(rows, "generation-unbounded", PROVENANCE,
               lambda t: t.replace("MAX_GENERATION = 3", "MAX_GENERATION = 10_000_000")) and ok

    # The plan itself stops refusing Platinum in CANONICAL_ROWS.
    ok = plant(rows, "plan-drops-the-rule", PLAN,
               lambda t: t.replace("Do not add Platinum to `CANONICAL_ROWS`",
                                   "Platinum may be added to `CANONICAL_ROWS`")) and ok

    r = run()
    rows.append(("restored", r.returncode == 0, "exit %d" % r.returncode))
    ok = (r.returncode == 0) and ok

    for name, passed, detail in rows:
        print("  %s %s -- %s" % ("ok" if passed else "FAIL", name, detail))
    print("population: %d examined, 0 skipped" % len(rows))
    print("plant medallion-memory: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
