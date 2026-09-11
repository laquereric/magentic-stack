#!/usr/bin/env python3
"""The bpmn.* seam exists, is reachable, and behaves.

Two halves, because either alone would be a hole.

BEHAVIOUR is bpmn_seam_probe.rb, driven here: it builds the gem's own migration
into an in-memory SQLite, seeds two versions of one definition_key, and asserts
what the seam will and will not do. That is why lib/bpmn_seam.rb is plain Ruby
rather than controller code -- a controller needs a booted Rails, which would
have left this gate asserting that a file mentions the right words.

SEAM WIRING is checked here, because a seam nothing routes to is a class that
compiles. rag failed for exactly this reason once: the entrypoint did not know
its ROLE. The controller can be perfect and unreachable.

The rule under all of it (plan_vv-bpmn-bbo.md §14):

    Neither store is a place to mint identity.
    (definition_key, version, element_id) and integer PKs are.

FAILS CLOSED: no gem, no probe, or a probe that examines nothing is an error.
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population  # noqa: E402

ROOT = Path(os.environ["CHECK_ROOT"]) if os.environ.get("CHECK_ROOT") else Path(__file__).resolve().parents[2]
GEM = ROOT / "gems/vv-bpmn-bbo"
PROBE = ROOT / "tooling/bpmn/bpmn_seam_probe.rb"
SEAM = ROOT / "runtimes/mind-pod/app/lib/bpmn_seam.rb"
INITIALIZER = ROOT / "runtimes/mind-pod/app/config/initializers/rails_cpcp.rb"

# Declared and refused by name. Both are honest states, not gaps: v1 is
# schema-only so there is no importer, and the run tables are a record rather
# than an engine.
REFUSED_WRITES = ("bpmn.deploy", "bpmn.run.start")

errors: list[str] = []


def main() -> int:
    if not GEM.is_dir():
        print("FAIL: no gem at %s" % GEM, file=sys.stderr)
        emit_population(0)
        return 1

    sources = sorted((GEM / "lib").rglob("*.rb"))
    populated, _pop = emit_population(len(sources), skipped_reason="no vv-bpmn-bbo sources")
    if not populated:
        return 1

    # ---- wiring ----------------------------------------------------------
    if not SEAM.is_file():
        errors.append("no lib/bpmn_seam.rb; the logic would only be testable through a Rails boot")

    # Registered on BACK, in the projection the engine already serves -- NOT as
    # a ROLE of its own. These rows are domain state, ADR 0056 makes BACK the
    # writer, and a separate container would have to mount the same SQLite
    # beside BACK. A method nobody registers is a class that compiles, which is
    # how the rag container failed for real.
    if not INITIALIZER.is_file():
        errors.append("no config/initializers/rails_cpcp.rb")
    else:
        init = INITIALIZER.read_text(encoding="utf-8")
        for method in ("bpmn.definitions", "bpmn.definition", "bpmn.node",
                       "bpmn.run.stat", "bpmn.deploy", "bpmn.run.start"):
            if 'operation "%s"' % method not in init:
                errors.append("%s is not registered on BACK; an unregistered method is a "
                              "class that compiles" % method)
        # The RAISE, not the word. An earlier version of this check searched for
        # "KnownRefusal" anywhere in the file and was therefore satisfied by the
        # COMMENT above the adapter -- it stayed green with the raise swapped for
        # StandardError. Caught by its own plant.
        if "raise ::RailsOsiLevel8::KnownRefusal" not in init:
            errors.append(
                "bpmn refusals are not raised as KnownRefusal; they would travel a second "
                "refusal path instead of the one every other BACK refusal uses"
            )

    # A ROLE=bpmn container would be a store we do not have, and would mount the
    # pod SQLite beside BACK -- two writers on one file (ADR 0056).
    routes = ROOT / "runtimes/mind-pod/app/config/routes.rb"
    if routes.is_file() and 'when "bpmn"' in routes.read_text(encoding="utf-8"):
        errors.append(
            "routes.rb declares a ROLE=bpmn branch. BPMN rows are domain state and ADR 0056 "
            "puts those on BACK; a bpmn container would mount the same SQLite beside it"
        )

    if SEAM.is_file():
        body = SEAM.read_text(encoding="utf-8")
        for method in REFUSED_WRITES:
            if method not in body:
                errors.append("%s is not declared; an undeclared write reads as an oversight "
                              "rather than a decision" % method)
        if "bpmn_write_undecided" not in body:
            errors.append("writes do not refuse by name")
        if "identity_not_minted_here" not in body:
            errors.append(
                "the seam does not refuse an IRI as a key. plan §14: identity is "
                "(definition_key, version, element_id) and integer PKs, not a store's IRI"
            )
        if "bpmn_tables_missing" not in body:
            errors.append("un-migrated tables are not distinguished from an empty model")

    # The gem stays schema-only: the CPCP face does not leak back into it.
    for path in sources:
        text = path.read_text(encoding="utf-8")
        if "_cpcp" in text or "ActionController" in text:
            errors.append(
                "%s carries CPCP; plan_vv-bpmn-bbo.md is explicit that the gem is the database "
                "design and not the CPCP face" % path.relative_to(ROOT)
            )

    # ---- behaviour -------------------------------------------------------
    if not PROBE.is_file():
        errors.append("no bpmn_seam_probe.rb; the seam would be unexercised")
    else:
        proc = subprocess.run(
            ["bundle", "exec", "ruby", str(PROBE)],
            cwd=str(GEM), capture_output=True, text=True, timeout=600,
        )
        out = proc.stdout + proc.stderr
        m = re.search(r"population: (\d+) examined", out)
        examined = int(m.group(1)) if m else 0
        if examined == 0:
            errors.append("the seam probe examined nothing; a green run over an empty "
                          "population is worse than no check")
        if proc.returncode != 0:
            tail = "\n".join(out.strip().splitlines()[-14:])
            errors.append("seam probe failed (%d examined):\n%s" % (examined, tail))

    if errors:
        for e in errors:
            print("  FAIL %s" % e, file=sys.stderr)
        print("bpmn: FAIL (%d)" % len(errors), file=sys.stderr)
        return 1
    print("bpmn: OK (%d gem sources, %d seam assertions)" % (len(sources), examined))
    return 0


if __name__ == "__main__":
    sys.exit(main())
