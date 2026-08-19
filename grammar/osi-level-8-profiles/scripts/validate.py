#!/usr/bin/env python3
"""Validate all OSI Level 8 / CPCP profile shapes in one place.

For each profile-*/ directory:
  - profiles WITH valid/invalid example fixtures (3-8): every valid fixture must
    conform to the profile's closed SHACL shapes and every invalid one must fail;
  - profiles WITHOUT fixtures (1-2, the Cyborg Channel / reference-passing shape
    sets): the shapes must be well-formed SHACL Turtle (parse + non-empty).
"""
from __future__ import annotations
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def shapes_graph(profile_dir):
    from rdflib import Graph
    g = Graph()
    for sf in sorted(profile_dir.glob("shapes/*.ttl")):
        g.parse(sf.as_posix(), format="turtle")
    return g

def main():
    from pyshacl import validate as shacl_validate
    all_ok = True
    profiles = sorted(ROOT.glob("profile-*"))
    for pdir in profiles:
        shape_files = sorted(pdir.glob("shapes/*.ttl"))
        if not shape_files:
            continue
        examples = sorted(pdir.glob("examples/*.ttl"))
        sg = shapes_graph(pdir)
        print(f"== {pdir.name} == shapes={len(shape_files)} examples={len(examples)} triples={len(sg)}")
        if examples:
            for ex in examples:
                expect = "invalid" not in ex.name
                conforms, _g, text = shacl_validate(
                    data_graph=ex.as_posix(), shacl_graph=sg,
                    data_graph_format="turtle", inference="rdfs",
                    advanced=True, abort_on_first=False)
                ok = bool(conforms) == expect
                print(f"  {'PASS' if ok else 'FAIL'}: {ex.name} conforms={conforms} expected={expect}")
                if not ok:
                    print("       " + " ".join(text.split())[:200])
                all_ok &= ok
        else:
            ok = len(sg) > 0  # well-formed Turtle parsed above; non-empty
            print(f"  {'PASS' if ok else 'FAIL'}: shapes well-formed SHACL Turtle ({len(sg)} triples)")
            all_ok &= ok
    print("all 9 profiles:", "OK" if all_ok else "FAILED")
    return 0 if all_ok else 1

if __name__ == "__main__":
    try:
        import rdflib, pyshacl  # noqa: F401
    except ImportError as e:
        print(f"missing dependency: {e}. pip install pyshacl rdflib", file=sys.stderr)
        sys.exit(2)
    raise SystemExit(main())
