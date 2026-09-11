#!/usr/bin/env python3
"""vv-sdlc reaches callers through BACK, and review stays unskippable.

vv-sdlc's README draws the division this gate holds in place:

    No CPCP in this gem -- bpmn.* registers on magentic-stack BACK (BpmnSeam),
    which is the sole writer (ADR 0056). This gem is the seed + token engine
    that seam calls.

So two things are checked, and neither is sufficient alone.

BEHAVIOUR is sdlc_seam_probe.rb, driven here. Every assertion in it goes
through BpmnSeam rather than calling the engine, because testing the engine
would prove the engine works while the thing a caller can actually reach went
unexercised. The headline invariant is tested as ABSENCE: while HumanReview is
open there is no job for ObsCheck or End_ok, so there is nothing past review
for a caller to complete. The seam never has to say no; the token is not there.

WIRING is checked because a seam method nobody registers is a class that
compiles, and because the engine boundary has to stay narrow: bpmn.run.start
was once an unconditional refusal on the grounds that nothing advances a token.
vv-sdlc is that engine for exactly ONE definition_key, so the refusal had to
narrow rather than vanish -- a process with no engine still gets an instance
that never moves if you let it start.

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
GEM = ROOT / "gems/vv-sdlc"
PROBE = ROOT / "tooling/sdlc/sdlc_seam_probe.rb"
SEAM = ROOT / "runtimes/mind-pod/app/lib/bpmn_seam.rb"
INITIALIZER = ROOT / "runtimes/mind-pod/app/config/initializers/rails_cpcp.rb"

# The methods the sdlc half adds. Registered on BACK, served by BpmnSeam,
# implemented by the gem's engine.
SDLC_METHODS = ("bpmn.seed_sdlc", "bpmn.jobs", "bpmn.claim", "bpmn.complete")

errors: list[str] = []


def main() -> int:
    if not GEM.is_dir():
        print("FAIL: no gem at %s" % GEM, file=sys.stderr)
        emit_population(0)
        return 1

    sources = sorted((GEM / "lib").rglob("*.rb"))
    populated, _pop = emit_population(len(sources), skipped_reason="no vv-sdlc sources")
    if not populated:
        return 1

    # NO CPCP IN THE GEM. The engine is called by the seam; it does not become
    # a second seam of its own, which would make two things the writer.
    for path in sources:
        text = path.read_text(encoding="utf-8")
        if "_cpcp" in text or "ActionController" in text or "RailsCpcp" in text:
            errors.append(
                "%s carries CPCP. vv-sdlc's README is explicit that bpmn.* registers on BACK "
                "and this gem is the engine that seam calls; a second seam would make two "
                "things the writer (ADR 0056)" % path.relative_to(ROOT)
            )

    # REGISTERED ON BACK.
    if not INITIALIZER.is_file():
        errors.append("no config/initializers/rails_cpcp.rb")
    else:
        init = INITIALIZER.read_text(encoding="utf-8")
        for method in SDLC_METHODS:
            if 'operation "%s"' % method not in init:
                errors.append("%s is not registered on BACK; the seam serves a method no caller "
                              "can reach" % method)

    # THE ENGINE BOUNDARY STAYS NARROW.
    if not SEAM.is_file():
        errors.append("no lib/bpmn_seam.rb")
    else:
        body = SEAM.read_text(encoding="utf-8")
        if "sdlc_process?" not in body:
            errors.append(
                "bpmn.run.start does not ask whether an engine handles this definition_key. "
                "Starting a process with no engine writes an instance that never moves"
            )
        if "undecided_write(:run_start)" not in body:
            errors.append(
                "bpmn.run.start no longer refuses anything. vv-sdlc is an engine for ONE "
                "definition_key; the refusal had to narrow, not disappear"
            )
        if "sdlc_absent" not in body:
            errors.append(
                "the seam does not distinguish 'vv-sdlc is not loaded' from a domain refusal; "
                "an absent engine would surface as a process error"
            )
        for method in SDLC_METHODS:
            if '"%s"' % method not in body:
                errors.append("the seam does not dispatch %s" % method)

    # BEHAVIOUR.
    examined = 0
    if not PROBE.is_file():
        errors.append("no sdlc_seam_probe.rb; the seam would be unexercised")
    else:
        proc = subprocess.run(
            ["bundle", "exec", "ruby", str(PROBE)],
            cwd=str(GEM), capture_output=True, text=True, timeout=600,
        )
        out = proc.stdout + proc.stderr
        m = re.search(r"population: (\d+) examined", out)
        examined = int(m.group(1)) if m else 0
        if examined == 0:
            errors.append("the sdlc seam probe examined nothing; a green run over an empty "
                          "population is worse than no check")
        if proc.returncode != 0:
            tail = "\n".join(out.strip().splitlines()[-16:])
            errors.append("sdlc seam probe failed (%d examined):\n%s" % (examined, tail))

    if errors:
        for e in errors:
            print("  FAIL %s" % e, file=sys.stderr)
        print("sdlc: FAIL (%d)" % len(errors), file=sys.stderr)
        return 1
    print("sdlc: OK (%d gem sources, %d seam assertions)" % (len(sources), examined))
    return 0


if __name__ == "__main__":
    sys.exit(main())
