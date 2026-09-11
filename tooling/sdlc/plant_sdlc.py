#!/usr/bin/env python3
"""Plants for check_sdlc. Proves the gate fails when it should.

The one that matters most is `review-becomes-skippable`. AiSDLC.md's whole
claim is that agent output is a confident junior who has read every textbook
and worked at none of our companies, so human review is the bottleneck ON
PURPOSE. A process that lets a caller reach End_ok while review sits open has
removed the only thing it exists for, and it looks like it worked.

`engine-claims-everything` is the second: vv-sdlc is an engine for exactly one
definition_key, and if it claimed all of them then starting a process with no
engine would write an instance that never moves.

Restores every file it touches.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/sdlc/check_sdlc.py"
SEAM = ROOT / "runtimes/mind-pod/app/lib/bpmn_seam.rb"
INITIALIZER = ROOT / "runtimes/mind-pod/app/config/initializers/rails_cpcp.rb"
PROBE = ROOT / "tooling/sdlc/sdlc_seam_probe.rb"
GEM_LIB = ROOT / "gems/vv-sdlc/lib/vv/sdlc"
ENGINE = GEM_LIB / "engine.rb"
SEED = GEM_LIB / "seed.rb"
FORK_PROBE = GEM_LIB / "_plant_cpcp.rb"


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

    # REVIEW BECOMES SKIPPABLE. The token stops waiting at the user task, so a
    # job exists past review and the whole point of the process is gone.
    ok = plant(rows, "review-becomes-skippable", ENGINE,
               lambda t: t.replace(
                   "        kind = node.is_a?(Vv::BpmnBbo::UserTask) ? \"user\" : \"service\"",
                   "        if node.is_a?(Vv::BpmnBbo::UserTask)\n"
                   "          ai.update!(state: \"completed\", ended_at: Time.now.utc)\n"
                   "          place!(inst, next_node(node, outcome), outcome: outcome)\n"
                   "          return\n"
                   "        end\n"
                   "        kind = node.is_a?(Vv::BpmnBbo::UserTask) ? \"user\" : \"service\"")) and ok

    # An unclaimed review completes: the human never took it, and the diff
    # ships with a review row that nobody stood behind.
    ok = plant(rows, "unclaimed-review-completes", ENGINE,
               lambda t: t.replace(
                   'return refuse(:job_not_claimed, "HumanReview must be claimed by an Actor first") unless job.state == "claimed"',
                   'nil unless job.state == "claimed"')) and ok

    # A review claimed by an actor that does not exist.
    ok = plant(rows, "claim-accepts-a-missing-actor", ENGINE,
               lambda t: t.replace(
                   "        unless defined?(::Vv::Base::Actor) && ::Vv::Base::Actor.exists?(actor_id)",
                   "        unless false")) and ok

    ok = plant(rows, "claim-accepts-no-actor", ENGINE,
               lambda t: t.replace(
                   'return refuse(:actor_required, "actor_id is required to claim a review") if actor_id.nil?',
                   "nil if actor_id.nil?")) and ok

    # THE ENGINE BOUNDARY. vv-sdlc claims every definition_key, so a process
    # with no engine gets an instance that never moves.
    ok = plant(rows, "engine-claims-everything", ENGINE,
               lambda t: t.replace(
                   'params.to_h["definition_key"].to_s == PACKAGE_KEY',
                   'true')) and ok

    # bpmn.run.start stops refusing anything at all.
    ok = plant(rows, "run-start-refuses-nothing", SEAM,
               lambda t: t.replace("        undecided_write(:run_start)",
                                   "        sdlc_call(:start, params)")) and ok

    # An absent engine surfaces as a process error instead of saying so.
    ok = plant(rows, "absent-engine-is-not-named", SEAM,
               lambda t: t.replace('"sdlc_absent"', '"start_failed"')) and ok

    # WIRING. A method the seam serves and BACK does not expose.
    ok = plant(rows, "method-unregistered", INITIALIZER,
               lambda t: t.replace('  operation "bpmn.claim",', '  operation "bpmn.claim_disabled",')) and ok

    # AgentTests becomes the ship gate -- the exact confusion the README warns
    # about, where internally coherent tests are treated as evidence.
    ok = plant(rows, "agent-tests-become-the-ship-gate", SEED,
               lambda t: t.replace('element_id: "RealityTest"', 'element_id: "RealityTest_removed"')) and ok

    # THE GEM GROWS A SEAM. Two writers instead of one (ADR 0056).
    existed = FORK_PROBE.exists()
    try:
        FORK_PROBE.write_text(
            "# planted: bpmn.* registers on BACK; this gem is the engine that seam calls\n"
            "class PlantedSdlcCpcp\n"
            "  def rpc = { path: \"/_cpcp/rpc\" }\n"
            "end\n",
            encoding="utf-8",
        )
        r = run()
        rows.append(("cpcp-leaks-into-the-gem", r.returncode != 0, "exit %d" % r.returncode))
        ok = (r.returncode != 0) and ok
    finally:
        if not existed:
            FORK_PROBE.unlink(missing_ok=True)

    # THE PROBE ITSELF checks nothing.
    ok = plant(rows, "probe-examines-nothing", PROBE,
               lambda t: t.replace('def check(name, ok, detail = "")\n  CHECKS << ',
                                   'def check(name, ok, detail = "")\n  return true\n  CHECKS << ')) and ok

    r = run()
    rows.append(("restored", r.returncode == 0, "exit %d" % r.returncode))
    ok = (r.returncode == 0) and ok

    for name, passed, detail in rows:
        print("  %s %s -- %s" % ("ok" if passed else "FAIL", name, detail))
    print("population: %d examined, 0 skipped" % len(rows))
    print("plant sdlc: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
