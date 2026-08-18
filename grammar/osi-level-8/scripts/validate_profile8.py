#!/usr/bin/env python3
"""Validate Profile 8 SHACL shapes against valid/invalid examples."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHAPES = ROOT / "shapes" / "osi-level-8-profile-8-architectural-learning-loop.ttl"
VALID = ROOT / "shapes" / "examples" / "profile-8-valid.ttl"
INVALID = ROOT / "shapes" / "examples" / "profile-8-invalid-missing-checkpoint.ttl"


def well_formed_turtle(path: Path) -> None:
    from rdflib import Graph

    g = Graph()
    g.parse(path.as_posix(), format="turtle")
    print(f"well-formed: {path.relative_to(ROOT)} triples={len(g)}")


def validate(data_path: Path, expect_conforms: bool) -> bool:
    from pyshacl import validate as shacl_validate

    conforms, _graph, text = shacl_validate(
        data_graph=data_path.as_posix(),
        shacl_graph=SHAPES.as_posix(),
        data_graph_format="turtle",
        shacl_graph_format="turtle",
        inference="rdfs",
        abort_on_first=False,
        meta_shacl=False,
        advanced=True,
        js=False,
        debug=False,
    )
    ok = bool(conforms) == expect_conforms
    status = "PASS" if ok else "FAIL"
    print(f"{status}: {data_path.name} conforms={conforms} expected={expect_conforms}")
    if not ok or (not conforms and expect_conforms is False):
        # always show a snippet for the invalid case
        if not conforms:
            lines = [ln for ln in text.splitlines() if ln.strip()][:12]
            print("  report:", " | ".join(lines)[:500])
    return ok


def main() -> int:
    try:
        import rdflib  # noqa: F401
    except ImportError:
        print("rdflib missing; pip install rdflib", file=sys.stderr)
        return 2

    for p in (SHAPES, VALID, INVALID):
        if not p.is_file():
            print(f"missing {p}", file=sys.stderr)
            return 2
        well_formed_turtle(p)

    try:
        import pyshacl  # noqa: F401
    except ImportError:
        print("pyshacl missing — well-formed Turtle only. pip install pyshacl")
        return 0

    ok_v = validate(VALID, expect_conforms=True)
    ok_i = validate(INVALID, expect_conforms=False)
    if ok_v and ok_i:
        print("profile-8 SHACL validation: OK")
        return 0
    print("profile-8 SHACL validation: FAILED", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
