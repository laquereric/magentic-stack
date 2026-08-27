#!/usr/bin/env python3
"""Validate the Profile 9 RDF projection against the Profile 9 normative shapes.

The shapes say what an ACIA document IS. The projection is one implementation of
them. Nothing checked that the second satisfied the first, so the projection
drifted: it emitted a prop table and a ux:parent edge that the closed
ComponentShape has no slot for, and omitted the GovernedFields it requires.

This runs the real projection over a real document and puts the output through
pyshacl. It is the only reading that settles whether an implementation conforms.

FAILS CLOSED: a projection that refuses, an empty graph, or any violation is a
failure. A conformance check with nothing to check reports success otherwise.
"""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHAPES = next((Path(__file__).resolve().parents[1]).glob("profile-9-*/shapes/*.ttl"))
GEM = ROOT / "rails-osi-level-8"

RUBY = r'''
$LOAD_PATH.unshift %(lib)
require "rails_osi_level_8/profile9/vocabulary"
require "rails_osi_level_8/profile9/acia"
require "rails_osi_level_8/profile9/translation_board"
require "rails_osi_level_8/profile9/projection"
doc = RailsOsiLevel8::Profile9::Acia.translation_board_document
res = RailsOsiLevel8::Profile9::Projection.triples(doc)
abort("projection refused: #{res[:reason]} #{res[:because]}") unless res[:ok]
puts res[:triples]
'''


def main():
    if not GEM.is_dir():
        print(f"FAIL: {GEM} not found", file=sys.stderr)
        return 1

    proc = subprocess.run(["ruby", "-e", RUBY], cwd=GEM, capture_output=True, text=True)
    if proc.returncode != 0:
        print(f"FAIL: could not project a document: {proc.stderr.strip()[:400]}", file=sys.stderr)
        return 1

    nt = proc.stdout
    if not nt.strip():
        print("FAIL: the projection produced no triples", file=sys.stderr)
        return 1

    from pyshacl import validate
    from rdflib import Graph

    data = Graph()
    try:
        data.parse(data=nt, format="nt")
    except Exception as exc:
        print(f"FAIL: the projection produced unparsable N-Triples: {exc}", file=sys.stderr)
        return 1

    shapes = Graph()
    shapes.parse(SHAPES.as_posix(), format="turtle")

    conforms, _g, text = validate(data_graph=data, shacl_graph=shapes,
                                  advanced=True, abort_on_first=False)
    if not conforms:
        violations = text.split("Constraint Violation")[1:]
        print(f"PROFILE 9 PROJECTION DOES NOT CONFORM: {len(violations)} violation(s)", file=sys.stderr)
        for block in violations[:12]:
            for line in block.splitlines():
                if "Message:" in line or "Focus Node:" in line:
                    print("  " + line.strip(), file=sys.stderr)
        return 1

    print(f"Profile 9 projection conforms: {len(data)} triples, 0 violations")
    return 0


if __name__ == "__main__":
    try:
        import pyshacl, rdflib  # noqa: F401
    except ImportError as exc:
        print(f"missing dependency: {exc}. pip install pyshacl rdflib", file=sys.stderr)
        sys.exit(2)
    raise SystemExit(main())
