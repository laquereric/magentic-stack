#!/usr/bin/env python3
"""Plants for check_bpmn. Proves the gate fails when it should.

The two that matter most restore the failures this seam was shaped to prevent:

  iri-accepted-as-a-key   the seam starts naming rows by an identifier it did
                          not author, which is plan §14's "neither store is a
                          place to mint identity" read backwards
  route-missing           the controller is perfect and unreachable. This is
                          exactly how the rag container failed for real -- the
                          entrypoint did not know its ROLE -- and it is the
                          failure a structural gate exists to catch

Restores every file it touches.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/bpmn/check_bpmn.py"
SEAM = ROOT / "runtimes/mind-pod/app/lib/bpmn_seam.rb"
ROUTES = ROOT / "runtimes/mind-pod/app/config/routes.rb"
INITIALIZER = ROOT / "runtimes/mind-pod/app/config/initializers/rails_cpcp.rb"
PROBE = ROOT / "tooling/bpmn/bpmn_seam_probe.rb"
GEM_LIB = ROOT / "gems/vv-bpmn-bbo/lib/vv/bpmn_bbo"
SPEC_IRI = GEM_LIB / "spec_iri.rb"
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

    # IDENTITY. The seam accepts an IRI as a key.
    ok = plant(rows, "iri-accepted-as-a-key", SEAM,
               lambda t: t.replace("MINTED_KEYS = %w[spec_iri iri graph_iri uri].freeze",
                                   "MINTED_KEYS = [].freeze")) and ok

    # spec_iri stops being derived from the version, so two versions of one
    # element_id collapse to one identity -- the exact thing the grain exists
    # to keep apart.
    ok = plant(rows, "spec-iri-drops-the-version", SPEC_IRI,
               lambda t: t.replace('"urn:mm:bpmn:#{key}:#{ver.version}:#{element_id}"',
                                   '"urn:mm:bpmn:#{key}:#{element_id}"')) and ok

    # ABSENT == EMPTY. A version nobody asked for is served in place of the one
    # that does not exist. This is the silent-wrong-answer shape rather than a
    # crash: the caller gets a real definition back and no signal that it is not
    # the one they named.
    ok = plant(rows, "missing-version-served-silently", SEAM,
               lambda t: t.replace(
                   '    if ver.nil?\n      return [nil, nil, fail_with(404, "version_missing",',
                   '    ver ||= pkg.definition_versions.order(:version).first\n'
                   '    if ver.nil?\n      return [nil, nil, fail_with(404, "version_missing",')) and ok

    # MIGRATED == EMPTY. Un-migrated tables read as "no definitions", which
    # tells an operator their model is empty when it is absent.
    ok = plant(rows, "unmigrated-reads-as-empty", SEAM,
               lambda t: t.replace(
                   '    fail_with(503, "bpmn_tables_missing", { "because" => e.message.to_s[0, 200] })',
                   '    ok("definitions" => [])')) and ok

    # WRITES. A refusal quietly becomes a success.
    ok = plant(rows, "write-stops-refusing", SEAM,
               lambda t: t.replace(
                   '    fail_with(409, "bpmn_write_undecided", { "operation" => op.to_s, "because" => because })',
                   '    ok("deployed" => true)')) and ok

    ok = plant(rows, "write-undeclared", SEAM,
               lambda t: t.replace('when "bpmn.deploy" then undecided_write(:deploy)\n', "")) and ok

    # TRUNCATION lies: a capped list claims to be complete.
    ok = plant(rows, "truncation-hidden", SEAM,
               lambda t: t.replace('"truncated" => total > @max_nodes,', '"truncated" => false,')) and ok

    # WIRING. A method nobody registers is a class that compiles -- the failure
    # the rag container actually had, where the entrypoint did not know its ROLE.
    ok = plant(rows, "method-unregistered", INITIALIZER,
               lambda t: t.replace('  operation "bpmn.node",', '  operation "bpmn.node_disabled",')) and ok

    # Refusals stop travelling the path every other BACK refusal uses, so a
    # bpmn refusal would surface differently from every neighbour.
    ok = plant(rows, "refusals-leave-the-known-path", INITIALIZER,
               lambda t: t.replace("::RailsOsiLevel8::KnownRefusal", "::StandardError")) and ok

    # A ROLE=bpmn container: a store we do not have, mounting the pod SQLite
    # beside BACK -- two writers on one file (ADR 0056).
    ok = plant(rows, "bpmn-becomes-a-container", ROUTES,
               lambda t: t.replace('  when "persist"',
                                   '  when "bpmn"\n    post "/_cpcp/rpc", to: "bpmn_cpcp#rpc"\n  when "persist"')) and ok

    # THE GEM STAYS SCHEMA-ONLY. A CPCP face leaking back into it.
    existed = FORK_PROBE.exists()
    try:
        FORK_PROBE.write_text(
            "# planted: the gem is the database design, not the CPCP face\n"
            "class PlantedCpcp < ActionController::Base\n"
            "  def rpc = render(json: { ok: true, path: \"/_cpcp/rpc\" })\n"
            "end\n",
            encoding="utf-8",
        )
        r = run()
        rows.append(("cpcp-leaks-into-the-gem", r.returncode != 0, "exit %d" % r.returncode))
        ok = (r.returncode != 0) and ok
    finally:
        if not existed:
            FORK_PROBE.unlink(missing_ok=True)

    # THE PROBE ITSELF. A gate whose behavioural half checks nothing.
    ok = plant(rows, "probe-examines-nothing", PROBE,
               lambda t: t.replace("def check(name, ok, detail = \"\")\n  CHECKS << ",
                                   "def check(name, ok, detail = \"\")\n  return true\n  CHECKS << ")) and ok

    r = run()
    rows.append(("restored", r.returncode == 0, "exit %d" % r.returncode))
    ok = (r.returncode == 0) and ok

    for name, passed, detail in rows:
        print("  %s %s -- %s" % ("ok" if passed else "FAIL", name, detail))
    print("population: %d examined, 0 skipped" % len(rows))
    print("plant bpmn: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
