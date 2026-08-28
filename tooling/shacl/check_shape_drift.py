#!/usr/bin/env python3
"""Fail when a closed shape and its runtime enforcement disagree.

WHY THIS EXISTS. "The shape" is two artifacts:

  the TTL     gems/osi-level-8-profiles/.../shapes/*.ttl -- declares the
              constraints, validated by pyshacl in Gate 2, and NEVER EXECUTED by
              the server (see RailsOsiLevel8::Grounding: mm-shacl-reader is not
              wired in-process).
  the Ruby    Grounding.closed_shape_violations -- actually refuses live
              requests, and until now was validated by nothing.

So a constraint could be tightened in SHACL, pass Gate 2 with its fixtures, and
change nothing about what the seam admits: a green gate reporting on a document
the server does not read. This checker is the thing that notices.

WHICH CONSTRAINTS NEED A RUNTIME TWIN. Not all of them. `sh:maxCount 1` on a
scalar is a fact about RDF cardinality -- a JSON parameter cannot appear twice --
so requiring a Ruby counterpart for it would manufacture busywork. What must have
a counterpart is anything that can REFUSE a request a client could actually send:

  sh:minCount >= 1     required
  sh:maxCount 0        forbidden (server-authoritative field)
  sh:in                closed vocabulary
  sh:minInclusive /
  sh:maxInclusive      range
  sh:minLength         non-empty

FAILS CLOSED. Unreadable inputs, a shapes file that parses to nothing, or zero
shape/case pairs discovered are all errors -- a drift check that finds nothing to
compare and reports success is worse than no drift check.
"""
from __future__ import annotations
import json, os, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GROUNDING = ROOT / "gems/rails-osi-level-8/lib/rails_osi_level_8/grounding.rb"
SHAPE_DIRS = [ROOT / "gems/osi-level-8-profiles"]

# Constraints that a live request can violate, and therefore need enforcement.
ENFORCEABLE = {
    "minCount": lambda v: int(v) >= 1,
    "maxCount": lambda v: int(v) == 0,
    "minInclusive": lambda v: True,
    "maxInclusive": lambda v: True,
    "minLength": lambda v: True,
    "in": lambda v: True,
}


def canon(name: str) -> str:
    """One spelling for a property across both artifacts.

    The TTL says `ses:sessionId` and `cpcp:idempotencyKey`; the Ruby checks the
    JSON parameter `session_id` and writes the path as `cpcp:idempotencyKey`.
    Same property, three spellings -- so compare a normal form rather than the
    text, or the checker reports drift that is only punctuation.
    """
    name = name.split(":")[-1].split("#")[-1].split("/")[-1]
    name = re.sub(r"(?<!^)(?=[A-Z])", "_", name)
    return name.lower()


def shapes_with_enforceable_constraints():
    """{shape local name -> {canonical property -> [constraint names]}} from the TTL."""
    from rdflib import Graph, Namespace, RDF
    SH = Namespace("http://www.w3.org/ns/shacl#")

    files = sorted(p for d in SHAPE_DIRS for p in d.glob("profile-*/shapes/*.ttl"))
    if not files:
        die("no shapes/*.ttl found under " + ", ".join(str(d) for d in SHAPE_DIRS))

    g = Graph()
    for f in files:
        g.parse(f.as_posix(), format="turtle")
    if len(g) == 0:
        die("shapes parsed to an empty graph")

    out = {}
    for shape in g.subjects(RDF.type, SH.NodeShape):
        local = str(shape).split("#")[-1].split("/")[-1]
        props = {}
        for pshape in g.objects(shape, SH.property):
            path = g.value(pshape, SH.path)
            if path is None:
                continue
            needed = []
            for cname, is_enforceable in ENFORCEABLE.items():
                for val in g.objects(pshape, SH[cname]):
                    try:
                        if is_enforceable(val):
                            needed.append(cname)
                    except (TypeError, ValueError):
                        needed.append(cname)
            if needed:
                props.setdefault(canon(str(path)), []).extend(needed)
        if props:
            out[local] = props
    return out, files


def grounding_cases():
    """{shape name -> {canonical property checked}} from the Ruby case statement."""
    if not GROUNDING.is_file():
        die("cannot read " + str(GROUNDING))
    src = GROUNDING.read_text()

    # Split the case into `when "A", "B"` blocks and read the violation paths in each.
    blocks = re.split(r"\n      when ", src)
    cases = {}
    for block in blocks[1:]:
        head, _, body = block.partition("\n")
        # a `when` may carry several shape names, and may wrap onto more lines
        names = re.findall(r'"([A-Za-z0-9]+::[A-Za-z0-9]+Shape)"', head + body.split("\n\n")[0])
        paths = set()
        for m in re.finditer(r'violation\(graph,\s*"([^"]+)"', body):
            paths.add(canon(m.group(1)))
        for n in names:
            cases.setdefault(n.split("::")[-1], set()).update(paths)
    if not cases:
        die("no `when \"X::YShape\"` cases found in grounding.rb")
    return cases


def die(msg):
    print("FAIL-CLOSED: " + msg, file=sys.stderr)
    sys.exit(2)


def main():
    try:
        import rdflib  # noqa: F401
    except ImportError as e:
        die("missing dependency: %s. pip install -r tooling/shacl/requirements.txt" % e)

    ttl, files = shapes_with_enforceable_constraints()
    ruby = grounding_cases()

    # Only shapes present in BOTH are comparable. A TTL shape with no Ruby case is
    # not drift -- Grounding now refuses unimplemented shapes outright, which is a
    # different (and louder) failure than silent divergence.
    paired = sorted(set(ttl) & set(ruby))
    print("shape files: %d   TTL shapes with enforceable constraints: %d   runtime cases: %d"
          % (len(files), len(ttl), len(ruby)))
    if not paired:
        die("no shape has BOTH a TTL definition and a runtime case; nothing was compared")

    drift = []
    for shape in paired:
        want = ttl[shape]
        have = ruby[shape]
        missing = {p: cs for p, cs in want.items() if p not in have}
        extra = sorted(have - set(want))
        status = "ok  " if not missing and not extra else "DRIFT"
        print("  %s %s  (%d constrained, %d enforced)" % (status, shape, len(want), len(have)))
        for p, cs in sorted(missing.items()):
            print("        SHACL constrains %-18s (%s) -- nothing refuses it at runtime"
                  % (p, ", ".join(sorted(set(cs)))))
            drift.append((shape, p, "unenforced"))
        for p in extra:
            print("        runtime refuses  %-18s -- the shape does not say so" % p)
            drift.append((shape, p, "undeclared"))

    print()
    print("%d shape(s) compared, %d drift(s)" % (len(paired), len(drift)))

    # CARRY THE DENOMINATORS. "0 drift" is true of the shapes that were COMPARED,
    # and reads as a statement about the profile set. Printing 105/15/5 to stdout
    # left the ratio in a log nobody keeps; the gate report -- and through it the
    # signed bundle -- said only pass.
    #
    # No "gate"/"status" pair here on purpose: assemble_bundle picks up any JSON
    # carrying both as a gate report, and this would arrive as a ninth gate and be
    # flagged unexpected against gates_expected.
    report = {
        "check": "shape-drift",
        "result": "pass" if not drift else "fail",
        "tool": "tooling/shacl/check_shape_drift.py",
        "shape_files": len(files),
        "ttl_shapes_with_enforceable_constraints": len(ttl),
        "runtime_cases": len(ruby),
        "shapes_compared": len(paired),
        "drift_count": len(drift),
        "drifts": [{"shape": d[0], "property": d[1], "kind": d[2]} for d in drift],
        # Said in the artifact rather than left for a reader to infer from two
        # numbers that look like a ratio and are not.
        "coverage_note": ("compared %d of %d TTL shapes carrying enforceable constraints; "
                          "the rest have no runtime case, which REFUSES rather than "
                          "validating clean" % (len(paired), len(ttl))),
    }
    out = os.environ.get("EVIDENCE_OUT", "evidence/shape-drift.json")
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    with open(out, "w") as f:
        json.dump(report, f, indent=2)
    print("wrote %s" % out)

    if drift:
        print("the specification and the enforcement disagree; a green SHACL gate does "
              "not mean the seam refuses what the shape forbids")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
