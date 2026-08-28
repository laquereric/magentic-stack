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
# BOTH HOMES. The canonical profile shapes and the ones the RUNTIME pins are
# different documents -- rails-osi-level-8/data/osi-level-8/profile-9-ghis.ttl
# carries the P9 operation shapes, which the canonical copy does not have, and
# nothing read it. It is the file config.shape_root points at, so its SHA-256 is
# what lands in shape_digest on every admission record.
SHAPE_DIRS = [ROOT / "gems/osi-level-8-profiles"]
SHAPE_FILES = sorted((ROOT / "gems/rails-osi-level-8/data/osi-level-8").glob("*.ttl"))

# P9 does not enforce through Grounding. It enforces per operation, in two calls:
#   Request.closed!(params, X_KEYS)  the closed set  -- sh:closed + the properties
#   Request.require_cid!(params, k)  a required key  -- sh:minCount 1
# Comparing P9 shapes against Grounding would pair nothing and quietly raise the
# denominator, which is the failure this fix exists to correct.
P9_SOURCES = [ROOT / "gems/rails-osi-level-8/lib/rails_osi_level_8/profile9/pulls.rb",
              ROOT / "gems/rails-osi-level-8/lib/rails_osi_level_8/profile9/mutations.rb"]
P9_VOCAB = ROOT / "gems/rails-osi-level-8/lib/rails_osi_level_8/profile9/vocabulary.rb"

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

    files = sorted(p for d in SHAPE_DIRS for p in d.glob("profile-*/shapes/*.ttl")) + SHAPE_FILES
    if not files:
        die("no shapes/*.ttl found under " + ", ".join(str(d) for d in SHAPE_DIRS))

    g = Graph()
    for f in files:
        g.parse(f.as_posix(), format="turtle")
    if len(g) == 0:
        die("shapes parsed to an empty graph")

    out, all_props = {}, {}
    for shape in g.subjects(RDF.type, SH.NodeShape):
        local = str(shape).split("#")[-1].split("/")[-1]
        props, declared = {}, set()
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
            declared.add(canon(str(path)))
            if needed:
                props.setdefault(canon(str(path)), []).extend(needed)
        if props or declared:
            out[local] = props
            all_props[local] = declared
    return out, files, all_props


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

    ttl, files, ttl_all = shapes_with_enforceable_constraints()
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

    # --- P9: enforced per operation, not through Grounding ---
    p9 = p9_enforcement()
    p9_paired = sorted(set(p9) & set(ttl_all))
    if p9:
        print("  -- P9 (Request.closed! / require_cid!) --")
    for shape in p9_paired:
        declared = ttl_all.get(shape, set())
        required = {prop for prop, cs in ttl.get(shape, {}).items() if "minCount" in cs}
        permits, requires = p9[shape]["permits"], p9[shape]["requires"]

        unenforced = sorted(required - requires)
        # A key the handler PERMITS that the closed shape never declared: the
        # runtime accepts what the shape forbids. The dangerous direction.
        undeclared = sorted(permits - declared)

        status = "ok  " if not unenforced and not undeclared else "DRIFT"
        print("  %s %s  (%d declared, %d permitted, %d required)"
              % (status, shape, len(declared), len(permits), len(required)))
        for prop in unenforced:
            print("        SHACL requires    %-20s -- no require_cid! enforces it" % prop)
            drift.append((shape, prop, "unenforced"))
        for prop in undeclared:
            print("        allow-list permits %-19s -- the closed shape does not declare it" % prop)
            drift.append((shape, prop, "undeclared"))

    paired = paired + p9_paired

    # the two homes: parse the runtime tree (nothing else does) and guard the overlap
    cross = cross_tree_check()
    drift.extend(cross)

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
        "cross_tree_problems": len(cross),
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




def p9_enforcement():
    """{shape -> {permits, requires}} read from the P9 handlers.

    P9 does not enforce through Grounding. It enforces per operation, in two calls:

        Request.closed!(params, X_KEYS)   what the operation PERMITS  (sh:closed)
        Request.require_cid!(params, k)   what it REQUIRES            (sh:minCount 1)

    Pairing P9 shapes against Grounding instead would match nothing while raising
    the denominator -- the exact failure this function exists to correct.
    """
    if not P9_VOCAB.is_file():
        return {}
    vocab = P9_VOCAB.read_text()
    ops = dict(re.findall(r'name:[ ]*"(ux[.][a-z.]+)".*?request_shape:[ ]*"P9::([A-Za-z]+)"',
                          vocab, re.S))
    # ux.journey.list -> journey_list ; ux.acia.mutate.propose -> acia_mutate_propose
    by_method = {op.replace("ux.", "", 1).replace(".", "_"): shape for op, shape in ops.items()}

    by_meth, meth_shape = {}, {}
    for path in P9_SOURCES:
        if not path.is_file():
            continue
        text = path.read_text()
        consts = {m.group(1): set(m.group(2).split())
                  for m in re.finditer(r'([A-Z_]*KEYS)[ ]*=[ ]*%w\[([^\]]*)\]', text, re.S)}
        for m in re.finditer(r'\n      def ([a-z_]+)[(](.*?)\n      end\n', text, re.S):
            meth, body = m.group(1), m.group(2)
            permits = set()
            for c in re.findall(r'closed![(]params,[ ]*([A-Z_]+)[)]', body):
                permits |= consts.get(c, set())
            requires = set(re.findall(r'require_cid![(]params,[ ]*"([A-Za-z_]+)"', body))
            # P9 requires a key three ways, not one: require_cid!, an explicit
            # check raising KnownRefusal with a "missing" payload, and DELEGATION
            # to another handler. Reading only the first reported successor,
            # originNodeId and pageCid as unenforced when all three are enforced.
            requires |= set(re.findall(r'"missing"[ ]*=>[ ]*"([A-Za-z_]+)"', body))
            calls = set(re.findall(r'\n        (?:base = )?([a-z_]+)[(]load_params[)]', body))
            calls |= set(re.findall(r'= ([a-z_]+)[(]load_params[)]', body))
            by_meth[meth] = {"permits": permits, "requires": requires, "calls": calls}
            if meth in by_method:
                meth_shape[meth] = by_method[meth]

    # Resolve one level of delegation. An over-approximation on purpose: a checker
    # that cries wolf is the red X that teaches people to ignore red Xs, so where
    # it cannot tell, it declines to report.
    for meth, data in by_meth.items():
        for callee in data["calls"]:
            if callee in by_meth:
                data["requires"] |= by_meth[callee]["requires"]

    out = {}
    for meth, shape in meth_shape.items():
        d = by_meth[meth]
        if d["permits"] or d["requires"]:
            out[shape] = {"permits": {canon(x) for x in d["permits"]},
                          "requires": {canon(x) for x in d["requires"]}}
    return out




def _shape_props(paths):
    """{shape local name -> {property -> sorted constraint names}} for one tree."""
    from rdflib import Graph, RDF, Namespace
    SH = Namespace("http://www.w3.org/ns/shacl#")
    g = Graph()
    parsed, failed = [], []
    for p in paths:
        try:
            g.parse(p.as_posix(), format="turtle")
            parsed.append(p)
        except Exception as e:  # noqa: BLE001
            failed.append((p, e.__class__.__name__))
    out = {}
    for s in g.subjects(RDF.type, SH.NodeShape):
        local = str(s).split("#")[-1].split("/")[-1]
        props = {}
        for ps in g.objects(s, SH.property):
            path = g.value(ps, SH.path)
            if path is None:
                continue
            name = canon(str(path))
            props[name] = tuple(sorted(
                str(pred).split("#")[-1] for pred, _ in g.predicate_objects(ps)
                if str(pred).split("#")[-1] != "path"))
        out[local] = props
    return out, parsed, failed


def cross_tree_check():
    """The two homes: the canonical profile shapes and the ones the runtime PINS.

    They are not two copies of one document -- canonical carries the domain/record
    shapes and the runtime tree carries the OPERATION request/response shapes, 60
    of which exist nowhere else. Generating either from the other would delete
    them. What they DO share is an overlap that is duplicated outright, and this
    is the guard on it.

    Also parses every runtime file, because nothing else does: Gate 2 validates
    the canonical tree, and the runtime tree is the one whose SHA-256 lands in
    shape_digest on every admission record.
    """
    canon_files = sorted(p for d in SHAPE_DIRS for p in d.glob("profile-*/shapes/*.ttl"))
    cn, _, cn_failed = _shape_props(canon_files)
    rt, rt_parsed, rt_failed = _shape_props(SHAPE_FILES)

    print()
    print("  -- cross-tree (canonical vs the shapes the runtime pins) --")
    print("     runtime files parsed: %d   canonical shapes: %d   runtime shapes: %d"
          % (len(rt_parsed), len(cn), len(rt)))

    problems = []
    for path, err in cn_failed + rt_failed:
        print("     UNPARSEABLE %s (%s)" % (path.name, err))
        problems.append((path.name, "-", "unparseable"))

    shared = sorted(set(cn) & set(rt))
    for name in shared:
        if cn[name] != rt[name]:
            print("     DIVERGED %s -- the same shape name says different things in each tree"
                  % name)
            problems.append((name, "-", "diverged"))
    print("     %d shape(s) in both trees, %d diverged" % (len(shared), len(problems)))
    return problems


if __name__ == "__main__":
    sys.exit(main())
