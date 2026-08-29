#!/usr/bin/env python3
"""Validate mmg-acia's cognition projection against the Profile 2 shapes.

A tree of nodes produces two artifacts: something a person sees and something a
model reads. Profile 9 governs the first; Profile 2 governs the second -- a
bounded preview plus the portable handle a model dereferences for the whole
thing. This checks the second is what the profile says it is.

FAILS CLOSED: a projection that produces nothing, or unparsable output, is a
failure. A conformance check with nothing to check reports success otherwise.
"""
import os
import subprocess
import sys
from pathlib import Path

_STACK = Path(os.environ["CHECK_ROOT"]) if os.environ.get("CHECK_ROOT") else Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "tooling"))
from population import emit_population

# CHECK_ROOT is honoured so a planted empty tree can prove the guards below fire.
# Previously every path resolved from __file__, so this read the real repository
# whatever it was pointed at, and its FAILS CLOSED docstring was an assertion
# nothing could test.
HERE = _STACK / "gems" / "osi-level-8-profiles"
ROOT = _STACK / "gems"
SHAPES = HERE / "profile-2-reference-passing" / "shapes" / "ps1-p2.shacl.ttl"
GEM = ROOT / "mmg-acia"

RUBY = r'''
$LOAD_PATH.unshift %(lib)
require "mmg/acia/cognition_projection"
C = Mmg::Acia::CognitionProjection
root = { id: 1, entity_iri: "urn:mm:arc:example", value: "Arc flow",
         cognition_summary: "A pane over runs, briefs and the repo they touch." }
kids = [{ id: 2, entity_iri: "urn:mm:brief:example", preview_text: "A brief awaiting approval." },
        { id: 3, entity_iri: "urn:mm:repo:example", value: "8451ba8a" },
        { id: 4, entity_iri: nil, value: "a label with no referent" }]
puts C.tree_triples(root, descendants: kids)
'''


def main():
    if not SHAPES.is_file():
        print(f"FAIL: Profile 2 shapes not found at {SHAPES}", file=sys.stderr)
        return 1
    if not GEM.is_dir():
        print(f"FAIL: {GEM} not found", file=sys.stderr)
        return 1

    proc = subprocess.run(["ruby", "-e", RUBY], cwd=GEM, capture_output=True, text=True)
    if proc.returncode != 0:
        print(f"FAIL: cognition projection errored: {proc.stderr.strip()[:400]}", file=sys.stderr)
        return 1
    if not proc.stdout.strip():
        print("FAIL: the cognition projection produced no triples", file=sys.stderr)
        return 1

    from pyshacl import validate
    from rdflib import Graph

    data = Graph()
    try:
        data.parse(data=proc.stdout, format="nt")
    except Exception as exc:
        print(f"FAIL: unparsable N-Triples: {exc}", file=sys.stderr)
        return 1

    shapes = Graph()
    shapes.parse(SHAPES.as_posix(), format="turtle")
    conforms, _g, text = validate(data_graph=data, shacl_graph=shapes,
                                  advanced=True, abort_on_first=False)
    if not conforms:
        violations = text.split("Constraint Violation")[1:]
        print(f"COGNITION PROJECTION DOES NOT CONFORM: {len(violations)} violation(s)", file=sys.stderr)
        for block in violations[:10]:
            for line in block.splitlines():
                if "Message:" in line or "Focus Node:" in line:
                    print("  " + line.strip(), file=sys.stderr)
        return 1

    # The denominator: how many triples were examined. A conformance check over
    # an empty graph conforms trivially, which is not a pass.
    populated, _pop = emit_population(len(data))
    if not populated:
        return 1
    print(f"cognition projection conforms to Profile 2: {len(data)} triples, 0 violations")
    return 0


if __name__ == "__main__":
    try:
        import pyshacl, rdflib  # noqa: F401
    except ImportError as exc:
        print(f"missing dependency: {exc}. pip install pyshacl rdflib", file=sys.stderr)
        sys.exit(2)
    raise SystemExit(main())
