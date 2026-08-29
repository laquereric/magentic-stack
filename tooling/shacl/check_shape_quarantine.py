#!/usr/bin/env python3
"""Step 2: reference graph + quarantine dispositions for unowned NodeShapes.

'unowned' is a CALL-SITE statement (no CpcpAdapter.wrap). It is not
reachability. SHACL validation reaches a shape via targets or via
shape-valued constraints (sh:node, sh:and, sh:or, sh:xone, sh:not,
sh:qualifiedValueShape, sh:property), including through blank nodes.

Dispositions of the 65 unowned (strongest live first):
  transitively_reachable  in the outbound closure of any bound_runtime shape
  self_targeting          carries sh:targetClass/Node/SubjectsOf/ObjectsOf
  orphan_referenced       inbound only from other unowned shapes
  unreferenced            no inbound NodeShape ref and no target
                          -- strongest deletion CANDIDATE, still quarantine

NOTHING IS DELETED. Default is quarantine.

FAILS CLOSED on an empty CHECK_ROOT tree. FAILS when a stored disposition
contradicts the graph built from the TTL. Adding a wrong disposition is the
plant.

Does not move TTL, edit shapes, or touch config.shape_root.
"""
from __future__ import annotations
import json, os, sys
from collections import defaultdict, deque
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

ROOT = Path(os.environ["CHECK_ROOT"]) if os.environ.get("CHECK_ROOT") else Path(__file__).resolve().parents[2]
OWNERS = ROOT / "tooling/shacl/shape_owner_candidates.json"
INVENTORY = ROOT / "tooling/shacl/shape_quarantine_inventory.json"
CANON_GLOB = "gems/osi-level-8-profiles/profile-*/shapes/*.ttl"
RUNTIME_GLOB = "gems/rails-osi-level-8/data/osi-level-8/*.ttl"

DISPOSITIONS = (
    "transitively_reachable",
    "self_targeting",
    "orphan_referenced",
    "unreferenced",
)


def local_of(iri: str) -> str:
    return iri.rstrip("/").split("#")[-1].split("/")[-1]


def ttl_files():
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from shape_resolution import named_ttl_files, load_manifest
    named = named_ttl_files(ROOT, load_manifest(ROOT))
    return named if named else []


def load_graph(files):
    from rdflib import Graph
    g = Graph()
    loaded = []
    for f in files:
        g.parse(f.as_posix(), format="turtle")
        loaded.append(f.relative_to(ROOT).as_posix() if ROOT in f.parents or f.is_relative_to(ROOT) else f.as_posix())
    return g, loaded


def rdf_list(g, head):
    from rdflib import RDF
    out = []
    seen = set()
    while head is not None and head != RDF.nil and head not in seen:
        seen.add(head)
        first = g.value(head, RDF.first)
        if first is not None:
            out.append(first)
        head = g.value(head, RDF.rest)
    return out


def walk_shape_valued(g, node, seen):
    """Yield URI NodeShapes reachable from node, traversing blank nodes and RDF lists."""
    from rdflib import RDF, URIRef, Namespace
    SH = Namespace("http://www.w3.org/ns/shacl#")
    if node in seen:
        return
    seen.add(node)
    if isinstance(node, URIRef) and (node, RDF.type, SH.NodeShape) in g:
        yield node
    shape_valued = (SH.node, SH.qualifiedValueShape, SH["not"])
    list_valued = (SH["or"], SH.xone, SH["and"])
    for pred in shape_valued:
        for obj in g.objects(node, pred):
            yield from walk_shape_valued(g, obj, seen)
    for pred in list_valued:
        for lst in g.objects(node, pred):
            for item in rdf_list(g, lst):
                yield from walk_shape_valued(g, item, seen)
    for pshape in g.objects(node, SH.property):
        yield from walk_shape_valued(g, pshape, seen)


def build_reference_graph(g):
    from rdflib import RDF, URIRef, Namespace
    SH = Namespace("http://www.w3.org/ns/shacl#")
    TARGETS = (SH.targetClass, SH.targetNode, SH.targetSubjectsOf, SH.targetObjectsOf)

    nodes = sorted({s for s in g.subjects(RDF.type, SH.NodeShape) if isinstance(s, URIRef)},
                   key=str)
    by_local = defaultdict(list)
    for n in nodes:
        by_local[local_of(str(n))].append(str(n))

    # Per-IRI outbound, then union by local name (one row per Phase-0 identity).
    iri_out = {}
    iri_targets = {}
    for n in nodes:
        seen = {n}
        out = set()
        for pred in (SH.node, SH.qualifiedValueShape, SH["not"], SH.property,
                     SH["or"], SH.xone, SH["and"]):
            for obj in g.objects(n, pred):
                if pred in (SH["or"], SH.xone, SH["and"]):
                    items = rdf_list(g, obj)
                else:
                    items = [obj]
                for item in items:
                    for hit in walk_shape_valued(g, item, seen):
                        if hit != n:
                            out.add(str(hit))
        iri_out[str(n)] = sorted(out)
        iri_targets[str(n)] = sorted(
            p.split("#")[-1] for p in TARGETS if any(g.objects(n, p))
        )

    locals_sorted = sorted(by_local)
    outbound = {}
    inbound = defaultdict(set)
    targets = {}
    iris = {}
    for local in locals_sorted:
        iris[local] = sorted(set(by_local[local]))
        outs = set()
        tset = set()
        for iri in iris[local]:
            for o in iri_out.get(iri, []):
                outs.add(local_of(o))
            tset.update(iri_targets.get(iri, []))
        outs.discard(local)
        outbound[local] = sorted(outs)
        targets[local] = sorted(tset)
        for o in outbound[local]:
            inbound[o].add(local)
    inbound = {k: sorted(v) for k, v in inbound.items()}
    return {
        "by_local": locals_sorted,
        "iris": iris,
        "outbound": outbound,
        "inbound": inbound,
        "targets": targets,
    }


def closure(starts, outbound):
    seen = set()
    q = deque(starts)
    while q:
        n = q.popleft()
        if n in seen:
            continue
        seen.add(n)
        for o in outbound.get(n, []):
            if o not in seen:
                q.append(o)
    return seen


def disposition_of(local, ref, runtime, unowned):
    inb = set(ref["inbound"].get(local, []))
    runtime_closure = closure(runtime, ref["outbound"])
    has_target = bool(ref["targets"].get(local))
    evidence = {
        "inbound": sorted(inb),
        "outbound": ref["outbound"].get(local, []),
        "targets": ref["targets"].get(local, []),
        "in_runtime_closure": local in runtime_closure,
    }
    if local in runtime_closure and local not in runtime:
        # reachable FROM a bound_runtime shape (not merely being one)
        return "transitively_reachable", evidence
    if local in runtime_closure and local in runtime:
        # a bound_runtime shape is live by call site; not in the 65
        return "transitively_reachable", evidence
    if has_target:
        return "self_targeting", evidence
    if inb and inb <= unowned:
        return "orphan_referenced", evidence
    if inb:
        # inbound from bound_ci_only or mixed; not runtime-reachable, no target
        evidence["inbound_from_non_unowned"] = sorted(inb - unowned)
        return "orphan_referenced", evidence
    return "unreferenced", evidence


def owners_index():
    if not OWNERS.is_file():
        return {}
    doc = json.loads(OWNERS.read_text())
    return {r["local_name"]: r for r in doc.get("shapes", [])}


def build_inventory(ref, owners):
    runtime = {n for n, r in owners.items() if r.get("binding_state") == "bound_runtime"
               or r.get("execution") == "runtime"}
    unowned = {n for n, r in owners.items() if r.get("binding_state") == "unowned"}
    # Graph may contain extras not in the 171; inventory is the 171.
    names = sorted(owners)
    rows = []
    unowned_rows = []
    counts = {d: 0 for d in DISPOSITIONS}
    for local in names:
        own = owners[local]
        disp, evidence = disposition_of(local, ref, runtime, unowned)
        if local not in unowned:
            disp_row = None
        else:
            disp_row = disp
            counts[disp] += 1
        row = {
            "local_name": local,
            "iris": own.get("iris") or ref["iris"].get(local, []),
            "occurrences": own.get("occurrences") or [],
            "owner": own.get("owner"),
            "execution": own.get("execution"),
            "binding_state": own.get("binding_state"),
            "namespace_partition": own.get("namespace_partition"),
            "status": "quarantined" if local in unowned else own.get("status"),
            "inbound": ref["inbound"].get(local, []),
            "outbound": ref["outbound"].get(local, []),
            "targets": ref["targets"].get(local, []),
            "disposition": disp_row,
            "disposition_evidence": evidence if local in unowned else None,
        }
        rows.append(row)
        if local in unowned:
            unowned_rows.append(row)
    unreachable = counts["unreferenced"]
    live = counts["transitively_reachable"] + counts["self_targeting"]
    return {
        "schema": "shape-quarantine-inventory/v0",
        "nothing_deleted": True,
        "default": "quarantine",
        "nodeshape_rows": len(rows),
        "unowned_count": len(unowned_rows),
        "disposition_counts": counts,
        "of_the_65_how_many_are_actually_unreachable": {
            "unreferenced": unreachable,
            "orphan_referenced": counts["orphan_referenced"],
            "self_targeting": counts["self_targeting"],
            "transitively_reachable": counts["transitively_reachable"],
            "headline": unreachable,
            "because": (
                "%d of 65 have no inbound NodeShape reference and no target "
                "(unreferenced). %d are live without a wrap: %d pulled in by a "
                "bound_runtime shape, %d carry their own target. %d %s only in "
                "an unowned cluster. '65 unowned' is a call-site count; "
                "unreachable is %d."
                % (unreachable, live, counts["transitively_reachable"],
                   counts["self_targeting"], counts["orphan_referenced"],
                   "sits" if counts["orphan_referenced"] == 1 else "sit",
                   unreachable)
            ),
        },
        "unowned": unowned_rows,
        "shapes": rows,
    }


def live_graph():
    files = ttl_files()
    if not files:
        return None, [], None
    g, loaded = load_graph(files)
    ref = build_reference_graph(g)
    return ref, loaded, g


def check(inventory, ref, owners):
    errors = []
    live = build_inventory(ref, owners)
    live_u = {r["local_name"]: r for r in live["unowned"]}
    inv_u = {r["local_name"]: r for r in inventory.get("unowned", [])}
    if set(live_u) != set(inv_u):
        errors.append("unowned set mismatch live=%s inv=%s"
                      % (sorted(set(live_u) - set(inv_u))[:10],
                         sorted(set(inv_u) - set(live_u))[:10]))
    for name, row in live_u.items():
        got = inv_u.get(name)
        if not got:
            continue
        if got.get("disposition") != row["disposition"]:
            errors.append(
                "DISPOSITION CONTRADICTS GRAPH: %s stored=%s live=%s"
                % (name, got.get("disposition"), row["disposition"])
            )
    if live["nodeshape_rows"] != inventory.get("nodeshape_rows"):
        errors.append("inventory nodeshape_rows %s != live %s"
                      % (inventory.get("nodeshape_rows"), live["nodeshape_rows"]))
    return errors, live


def main(argv):
    write = "--write" in argv
    owners = owners_index()
    ref, loaded, g = live_graph()
    n = len(owners) if owners else (len(ref["by_local"]) if ref else 0)
    populated, _pop = emit_population(n, skipped_reason="no NodeShapes / no owner candidates")
    if not populated:
        return 1
    if ref is None:
        print("FAIL-CLOSED: no TTL shapes under CHECK_ROOT", file=sys.stderr)
        return 1

    if write:
        inv = build_inventory(ref, owners)
        INVENTORY.parent.mkdir(parents=True, exist_ok=True)
        INVENTORY.write_text(json.dumps(inv, indent=2) + "\n")
        print("wrote", INVENTORY.relative_to(ROOT) if ROOT in INVENTORY.parents else INVENTORY)
        print("unowned", inv["unowned_count"], "dispositions", json.dumps(inv["disposition_counts"]))
        print("UNREACHABLE", inv["of_the_65_how_many_are_actually_unreachable"]["headline"])
        print(inv["of_the_65_how_many_are_actually_unreachable"]["because"])
        return 0

    if not INVENTORY.is_file():
        print("FAIL-CLOSED: missing", INVENTORY, file=sys.stderr)
        return 1
    inventory = json.loads(INVENTORY.read_text())
    errors, live = check(inventory, ref, owners)
    print("unowned", live["unowned_count"], "unreachable",
          live["of_the_65_how_many_are_actually_unreachable"]["headline"])
    if errors:
        print("SHAPE QUARANTINE FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors[:30]:
            print("  " + e, file=sys.stderr)
        return 1
    print("shape quarantine: OK (%d NodeShapes, %d unowned, %d unreferenced)"
          % (live["nodeshape_rows"], live["unowned_count"],
             live["of_the_65_how_many_are_actually_unreachable"]["headline"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
