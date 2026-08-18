#!/usr/bin/env python3
"""Validate OSI Level 8 Profile 4–8 SHACL shapes (valid conforms, invalid fails)."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHAPES = ROOT / "shapes"
EX = SHAPES / "examples"

CASES = [
    (4, "osi-level-8-profile-4-durable-cyborg-execution.ttl",
     "profile-4-valid.ttl", "profile-4-invalid-missing-operationId.ttl"),
    (5, "osi-level-8-profile-5-biography-and-provenance.ttl",
     "profile-5-valid.ttl", "profile-5-invalid-missing-causalParent.ttl"),
    (6, "osi-level-8-profile-6-enterprise-authorization-evidence.ttl",
     "profile-6-valid.ttl", "profile-6-invalid-literal-secret.ttl"),
    (7, "osi-level-8-profile-7-observation-and-outcome.ttl",
     "profile-7-valid.ttl", "profile-7-invalid-missing-effectRef.ttl"),
    (8, "osi-level-8-profile-8-architectural-learning-loop.ttl",
     "profile-8-valid.ttl", "profile-8-invalid-missing-checkpoint.ttl"),
]


def well_formed(path: Path) -> int:
    from rdflib import Graph

    g = Graph()
    g.parse(path.as_posix(), format="turtle")
    return len(g)


def validate(data: Path, shapes: Path, expect: bool) -> bool:
    from pyshacl import validate as shacl_validate

    conforms, _g, text = shacl_validate(
        data_graph=data.as_posix(),
        shacl_graph=shapes.as_posix(),
        data_graph_format="turtle",
        shacl_graph_format="turtle",
        inference="rdfs",
        abort_on_first=False,
        meta_shacl=False,
        advanced=True,
        js=False,
        debug=False,
    )
    ok = bool(conforms) == expect
    mark = "PASS" if ok else "FAIL"
    print(f"  {mark}: {data.name} conforms={conforms} expected={expect}")
    if not conforms:
        line = " ".join(ln.strip() for ln in text.splitlines() if ln.strip())[:240]
        print(f"       {line}")
    return ok


def main() -> int:
    try:
        import rdflib  # noqa: F401
        import pyshacl  # noqa: F401
    except ImportError as e:
        print(f"missing dependency: {e}", file=sys.stderr)
        return 2

    all_ok = True
    for n, shape_name, valid_name, invalid_name in CASES:
        shapes = SHAPES / shape_name
        valid = EX / valid_name
        invalid = EX / invalid_name
        print(f"Profile {n}:")
        for p in (shapes, valid, invalid):
            if not p.is_file():
                print(f"  FAIL: missing {p}", file=sys.stderr)
                all_ok = False
                continue
            print(f"  well-formed {p.name} triples={well_formed(p)}")
        if shapes.is_file() and valid.is_file():
            all_ok &= validate(valid, shapes, True)
        if shapes.is_file() and invalid.is_file():
            all_ok &= validate(invalid, shapes, False)

    if all_ok:
        print("profiles 4–8 SHACL validation: OK")
        return 0
    print("profiles 4–8 SHACL validation: FAILED", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
