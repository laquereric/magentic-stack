#!/usr/bin/env python3
"""P10: keep the closed SHACL shapes and the Ruby allowlist in step.

Profile 10's contract lived only as a Ruby allowlist in
rails_osi_level_8/intent/validator.rb. Adding SHACL shapes fixes P10's invisibility
to Gate 2, but on its own it creates a worse problem: the same rule written in two
places drifts at two rates, and whichever copy a reader lands on is the one they
believe. This script is what makes them ONE rule with two expressions.

It compares, per intent type, the set of properties the shape admits against the
set the Ruby allowlist admits, and fails on any divergence in either direction.

FAILS CLOSED: if either side yields no types, that is an error, not a pass. A
drift check that silently finds nothing to compare is worse than no check, because
it reports success.
"""
from __future__ import annotations
import re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent.parent
TTL = ROOT / "profile-10-intent" / "shapes" / "profile-10-intent.ttl"
RUBY = REPO / "gems" / "rails-osi-level-8" / "lib" / "rails_osi_level_8" / "intent" / "validator.rb"

# @id is the node IRI and @type is rdf:type; neither is a SHACL property.
NOT_PROPERTIES = {"@id", "@type"}


def shapes_from_ttl(path):
    """Returns (shapes, error). Unparsable Turtle is a FAILURE, not a traceback --
    a drift check that crashes on a malformed shape file tells a reader the tool
    is broken when what is broken is the thing it was pointed at."""
    from rdflib import Graph
    from rdflib.namespace import SH
    g = Graph()
    try:
        g.parse(path.as_posix(), format="turtle")
    except Exception as exc:
        return {}, f"{path.name} is not parsable Turtle: {exc}"
    out = {}
    for shape, cls in g.subject_objects(SH.targetClass):
        name = str(cls).rsplit("#", 1)[-1]
        props = set()
        for pshape in g.objects(shape, SH.property):
            for p in g.objects(pshape, SH.path):
                props.add(str(p).rsplit("#", 1)[-1])
        out[name] = props
    return out, None


def allowlist_from_ruby(path):
    """Read SHAPE_PREDICATES. Regular by construction; unreadable = failure."""
    text = path.read_text(encoding="utf-8")
    m = re.search(r"COMMON\s*=\s*%w\[(.*?)\]", text, re.S)
    if not m:
        return {}, "could not read COMMON from validator.rb"
    common = set(m.group(1).split()) - NOT_PROPERTIES

    block = re.search(r"SHAPE_PREDICATES\s*=\s*\{(.*?)\n      \}\.freeze", text, re.S)
    if not block:
        return {}, "could not read SHAPE_PREDICATES from validator.rb"

    out = {}
    for name, extra in re.findall(r'"intent:(\w+)"\s*=>\s*COMMON\s*\+\s*%w\[(.*?)\]', block.group(1), re.S):
        out[name] = common | (set(extra.split()) - NOT_PROPERTIES)
    return out, None


def main():
    if not TTL.is_file():
        print(f"FAIL: shapes not found at {TTL}", file=sys.stderr)
        return 1
    if not RUBY.is_file():
        print(f"FAIL: validator not found at {RUBY}", file=sys.stderr)
        return 1

    ttl, ttl_err = shapes_from_ttl(TTL)
    if ttl_err:
        print(f"FAIL: {ttl_err}", file=sys.stderr)
        return 1
    ruby, err = allowlist_from_ruby(RUBY)
    if err:
        print(f"FAIL: {err}", file=sys.stderr)
        return 1
    if not ttl or not ruby:
        print(f"FAIL: nothing to compare (ttl={len(ttl)} ruby={len(ruby)})", file=sys.stderr)
        return 1

    problems = []
    for name in sorted(set(ttl) | set(ruby)):
        if name not in ttl:
            problems.append(f"{name}: in validator.rb, no SHACL shape")
            continue
        if name not in ruby:
            problems.append(f"{name}: has a SHACL shape, absent from validator.rb")
            continue
        only_ttl = sorted(ttl[name] - ruby[name])
        only_rb = sorted(ruby[name] - ttl[name])
        if only_ttl:
            problems.append(f"{name}: shape admits {only_ttl}, validator.rb does not")
        if only_rb:
            problems.append(f"{name}: validator.rb admits {only_rb}, shape does not")

    if problems:
        print("P10 SHAPE/ALLOWLIST DRIFT:", file=sys.stderr)
        for p in problems:
            print("  " + p, file=sys.stderr)
        return 1

    total = sum(len(v) for v in ttl.values())
    print(f"P10 alignment OK: {len(ttl)} types, {total} properties, shapes and validator.rb agree")
    return 0


if __name__ == "__main__":
    try:
        import rdflib  # noqa: F401
    except ImportError as e:
        print(f"missing dependency: {e}. pip install rdflib", file=sys.stderr)
        sys.exit(2)
    raise SystemExit(main())
