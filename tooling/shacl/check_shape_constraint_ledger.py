#!/usr/bin/env python3
"""Step 3: constraint ledger for the two profile-9 and two profile-11 TTL trees.

Four documents, two profile numbers. Same number does not mean the same
document. Union is unsafe: a stricter side silently changes either what
the seam admits or what the protocol claims.

This checker DESCRIBES divergence. It does not merge TTL, edit shapes, or
touch config.shape_root. It does not resolve a CONFLICT by preferring a
tree's values.

A row is one (shape, constraint-component) pair. Conflicts live in
`conflicts[]` -- that is the key this checker reads. A live DIFFERENT
missing from stored conflicts[] is an UNRESOLVED CONFLICT (the plant).
A stored conflict the live graph does not have is the other direction.

FAILS CLOSED on an empty CHECK_ROOT tree / zero pairs. FAILS when stored
pairs or conflicts[] contradict the graph built from the four documents.

Does not move TTL, edit shapes, or touch config.shape_root.
"""
from __future__ import annotations
import json, os, re, sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

ROOT = Path(os.environ["CHECK_ROOT"]) if os.environ.get("CHECK_ROOT") else Path(__file__).resolve().parents[2]
OWNERS = ROOT / "tooling/shacl/shape_owner_candidates.json"
LEDGER = ROOT / "tooling/shacl/shape_constraint_ledger.json"

DOCUMENTS = (
    {
        "profile": "9",
        "tree": "runtime_pin",
        "rel": "gems/rails-osi-level-8/data/osi-level-8/profile-9-ghis.ttl",
    },
    {
        "profile": "9",
        "tree": "canonical",
        "rel": "gems/osi-level-8-profiles/profile-9-governed-human-interaction-surface/shapes/osi-level-8-profile-9-ghis.shacl.ttl",
    },
    {
        "profile": "11",
        "tree": "runtime_pin",
        "rel": "gems/rails-osi-level-8/data/osi-level-8/profile-11-meaning.ttl",
    },
    {
        "profile": "11",
        "tree": "canonical",
        "rel": "gems/osi-level-8-profiles/profile-11-meaning/shapes/profile-11-meaning.ttl",
    },
)

DISPOSITIONS = (
    "retain-protocol",
    "retain-application",
    "retain-compatibility",
    "quarantine",
    "reject-as-invalid",
)

# Constraint components collected from a NodeShape itself.
NODE_COMPONENTS = (
    "targetClass", "targetNode", "targetSubjectsOf", "targetObjectsOf",
    "closed", "ignoredProperties", "and", "or", "xone", "not",
    "class", "datatype", "nodeKind", "node",
    "deactivated",
)

# Constraint components collected from a sh:property blank node.
# path is identity, not a row. severity/message are row fields, not rows.
PROP_COMPONENTS = (
    "minCount", "maxCount", "datatype", "class", "nodeKind", "node",
    "minInclusive", "maxInclusive", "minExclusive", "maxExclusive",
    "minLength", "maxLength", "pattern", "flags",
    "in", "hasValue", "equals", "disjoint", "lessThan", "lessThanOrEquals",
    "uniqueLang", "languageIn",
    "qualifiedValueShape", "qualifiedMinCount", "qualifiedMaxCount",
    "closed", "ignoredProperties",
    "and", "or", "xone", "not",
)

LIST_VALUED = {
    "in", "ignoredProperties", "and", "or", "xone", "languageIn",
}

SET_COMPARE = LIST_VALUED | {"targetClass", "targetNode", "targetSubjectsOf", "targetObjectsOf"}


def local_of(iri):
    return iri.rstrip("/").split("#")[-1].split("/")[-1]


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


def term_canon(g, t, list_ok=False):
    from rdflib import Literal, URIRef, BNode, RDF
    if t is None:
        return None
    if t == RDF.nil:
        return []
    if isinstance(t, URIRef):
        return str(t)
    if isinstance(t, Literal):
        v = t.toPython()
        if isinstance(v, bool):
            return bool(v)
        if isinstance(v, int) and not isinstance(v, bool):
            return int(v)
        return str(v)
    if isinstance(t, BNode):
        if list_ok:
            items = rdf_list(g, t)
            if items or t == RDF.nil:
                return [term_canon(g, x, list_ok=False) for x in items]
        return "_:" + str(t)
    return str(t)


def values_equal(component, a, b):
    if a == b:
        return True
    if a is None or b is None:
        return False
    if component in SET_COMPARE or (isinstance(a, list) and isinstance(b, list)):
        def bag(v):
            if not isinstance(v, list):
                v = [v]
            out = []
            for item in v:
                if isinstance(item, str) and (":" in item or "/" in item):
                    out.append(local_of(item))
                else:
                    out.append(item)
            return sorted(out, key=lambda x: json.dumps(x, sort_keys=True, default=str))
        return bag(a) == bag(b)
    return False


def how_diff(component, runtime, canonical):
    def show(v):
        if isinstance(v, list):
            return [local_of(x) if isinstance(x, str) and ("/" in x or "#" in x) else x for x in v]
        if isinstance(v, str) and ("/" in v or "#" in v):
            return local_of(v)
        return v
    return "runtime=%s canonical=%s" % (
        json.dumps(show(runtime), sort_keys=True, default=str),
        json.dumps(show(canonical), sort_keys=True, default=str),
    )


def shape_decl_lines(path: Path):
    found = {}
    if not path.is_file():
        return found
    for i, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        m = re.search(r"(?:[A-Za-z0-9_]+:)?([A-Za-z0-9_]+)\s+a\s+sh:NodeShape", line)
        if m:
            found[m.group(1)] = i
    return found


def extract_file(path: Path, profile: str, tree: str):
    from rdflib import Graph, Namespace, RDF, URIRef
    SH = Namespace("http://www.w3.org/ns/shacl#")
    g = Graph()
    g.parse(path.as_posix(), format="turtle")
    lines = shape_decl_lines(path)
    rel = path.relative_to(ROOT).as_posix() if ROOT in path.parents or path == ROOT else path.as_posix()
    rows = []  # dicts keyed later
    nodes = sorted(
        {s for s in g.subjects(RDF.type, SH.NodeShape) if isinstance(s, URIRef)},
        key=str,
    )
    for shape in nodes:
        local = local_of(str(shape))
        src = {"tree": tree, "file": rel, "line": lines.get(local), "shape_iri": str(shape)}
        # node-level
        for cname in NODE_COMPONENTS:
            pred = SH[cname]
            objs = list(g.objects(shape, pred))
            if not objs:
                continue
            list_ok = cname in LIST_VALUED
            if list_ok and len(objs) == 1:
                val = term_canon(g, objs[0], list_ok=True)
            elif len(objs) == 1:
                val = term_canon(g, objs[0], list_ok=False)
            else:
                val = [term_canon(g, o, list_ok=list_ok) for o in objs]
            sev = term_canon(g, g.value(shape, SH.severity), list_ok=False)
            msg = term_canon(g, g.value(shape, SH.message), list_ok=False)
            rows.append({
                "profile": profile,
                "shape_local": local,
                "path": None,
                "path_iri": None,
                "component": cname,
                "value": val,
                "severity": local_of(str(sev)) if isinstance(sev, str) and sev else sev,
                "message": msg,
                "source": src,
            })
        # property-level
        for pshape in g.objects(shape, SH.property):
            path_term = g.value(pshape, SH.path)
            if path_term is None:
                rows.append({
                    "profile": profile,
                    "shape_local": local,
                    "path": None,
                    "path_iri": None,
                    "component": "property-missing-path",
                    "value": None,
                    "severity": None,
                    "message": None,
                    "source": src,
                    "invalid": True,
                })
                continue
            path_iri = str(path_term)
            path_local = local_of(path_iri)
            sev = term_canon(g, g.value(pshape, SH.severity), list_ok=False)
            msg = term_canon(g, g.value(pshape, SH.message), list_ok=False)
            any_comp = False
            for cname in PROP_COMPONENTS:
                pred = SH[cname]
                objs = list(g.objects(pshape, pred))
                if not objs:
                    continue
                any_comp = True
                list_ok = cname in LIST_VALUED
                if list_ok and len(objs) == 1:
                    val = term_canon(g, objs[0], list_ok=True)
                elif len(objs) == 1:
                    val = term_canon(g, objs[0], list_ok=False)
                else:
                    val = [term_canon(g, o, list_ok=list_ok) for o in objs]
                rows.append({
                    "profile": profile,
                    "shape_local": local,
                    "path": path_local,
                    "path_iri": path_iri,
                    "component": cname,
                    "value": val,
                    "severity": local_of(str(sev)) if isinstance(sev, str) and sev else sev,
                    "message": msg,
                    "source": src,
                })
            if not any_comp:
                # a property shape that only names a path still constrains
                # existence of the predicate in a closed shape's property list
                rows.append({
                    "profile": profile,
                    "shape_local": local,
                    "path": path_local,
                    "path_iri": path_iri,
                    "component": "property",
                    "value": True,
                    "severity": local_of(str(sev)) if isinstance(sev, str) and sev else sev,
                    "message": msg,
                    "source": src,
                })
    return rows, len(nodes), len(g)


def pair_key(profile, shape_local, path, component):
    return "%s|%s|%s|%s" % (profile, shape_local, path or "", component)


def owners_index():
    if not OWNERS.is_file():
        return {}
    doc = json.loads(OWNERS.read_text())
    return {r["local_name"]: r for r in doc.get("shapes", [])}


def dispose(present_in, comparison, owner_rec, invalid):
    if invalid:
        return "reject-as-invalid", "property shape with no sh:path is not a constraint"
    owner = (owner_rec or {}).get("owner")
    execution = (owner_rec or {}).get("execution")
    status = (owner_rec or {}).get("status")
    binding = (owner_rec or {}).get("binding_state")
    runtime_bound = binding == "bound_runtime" or execution == "runtime"
    quarantined = status == "quarantined" or binding == "unowned"

    if present_in == "runtime_pin":
        if runtime_bound:
            return "retain-compatibility", (
                "present only in the runtime pin; currently enforced; "
                "this step does not drop enforced behavior"
            )
        if quarantined:
            return "quarantine", "present only in the runtime pin; unowned/quarantined"
        if owner == "application":
            return "retain-application", "present only in the runtime pin; application-owned"
        return "retain-compatibility", (
            "present only in the runtime pin; compatibility baseline even if not wrapped"
        )

    if present_in == "canonical":
        if quarantined:
            return "quarantine", "present only in the canonical tree; unowned/quarantined"
        if owner == "application":
            return "retain-application", "present only in the canonical tree; application-owned"
        return "retain-protocol", "present only in the canonical tree; protocol-owned"

    # both
    if comparison == "DIFFERENT":
        if runtime_bound:
            return "retain-compatibility", (
                "CONFLICT: both trees constrain this, values disagree. "
                "Shape is bound_runtime so the runtime pin is the compatibility "
                "baseline. Values are NOT chosen -- conflict stays unresolved."
            )
        if owner == "application":
            return "retain-application", (
                "CONFLICT: both trees constrain this, values disagree. "
                "Application-owned placement; values are NOT chosen."
            )
        return "retain-protocol", (
            "CONFLICT: both trees constrain this, values disagree. "
            "Protocol-owned placement; values are NOT chosen."
        )

    if quarantined and not runtime_bound:
        return "quarantine", "identical in both trees; unowned/quarantined"
    if owner == "application":
        return "retain-application", "identical in both trees; application-owned"
    return "retain-protocol", "identical in both trees; protocol-owned"


def build_ledger(extracted_by_doc, owners):
    # extracted_by_doc: list of (doc, rows, n_shapes, n_triples)
    by_key = defaultdict(lambda: {"runtime_pin": None, "canonical": None})
    docs_meta = []
    for doc, rows, n_shapes, n_triples in extracted_by_doc:
        docs_meta.append({
            "profile": doc["profile"],
            "tree": doc["tree"],
            "file": doc["rel"],
            "nodeshapes": n_shapes,
            "triples": n_triples,
            "constraint_rows": len(rows),
        })
        for row in rows:
            k = pair_key(row["profile"], row["shape_local"], row["path"], row["component"])
            slot = by_key[k][doc["tree"]]
            if slot is None:
                by_key[k][doc["tree"]] = row
            else:
                # same (shape,path,component) twice in one document
                if not values_equal(row["component"], slot["value"], row["value"]):
                    slot["value"] = [slot["value"], row["value"]]
                    slot["invalid"] = True
                # else duplicate identical -- ignore

    pairs = []
    for k in sorted(by_key):
        sides = by_key[k]
        rt, can = sides["runtime_pin"], sides["canonical"]
        sample = rt or can
        invalid = bool((rt and rt.get("invalid")) or (can and can.get("invalid")))
        if rt and can:
            present_in = "both"
            same = values_equal(sample["component"], rt["value"], can["value"]) and not invalid
            comparison = "IDENTICAL" if same else "DIFFERENT"
            how = None if same else how_diff(sample["component"], rt["value"], can["value"])
        elif rt:
            present_in = "runtime_pin"
            comparison = None
            how = None
        else:
            present_in = "canonical"
            comparison = None
            how = None

        owner_rec = owners.get(sample["shape_local"]) or {}
        disposition, evidence = dispose(present_in, comparison, owner_rec, invalid)
        bound_runtime = (
            owner_rec.get("binding_state") == "bound_runtime"
            or owner_rec.get("execution") == "runtime"
        )
        sources = []
        if rt:
            sources.append(rt["source"])
        if can:
            sources.append(can["source"])

        rec = {
            "key": k,
            "profile": sample["profile"],
            "shape_local": sample["shape_local"],
            "path": sample["path"],
            "path_iri": (rt["path_iri"] if rt else can["path_iri"]),
            "component": sample["component"],
            "cardinality": None,
            "value_runtime": None if not rt else rt["value"],
            "value_canonical": None if not can else can["value"],
            "present_in": present_in,
            "comparison": comparison,
            "how": how,
            "sources": sources,
            "severity": sample.get("severity"),
            "message": sample.get("message"),
            "owner": owner_rec.get("owner"),
            "execution": owner_rec.get("execution"),
            "binding_state": owner_rec.get("binding_state"),
            "status": owner_rec.get("status"),
            "bound_runtime": bool(bound_runtime),
            "disposition": disposition,
            "disposition_evidence": evidence,
            "conflict": comparison == "DIFFERENT",
            "conflict_resolved": False if comparison == "DIFFERENT" else None,
        }
        # cardinality convenience when the component is a count
        if sample["component"] in ("minCount", "maxCount"):
            rec["cardinality"] = {
                "component": sample["component"],
                "runtime": None if not rt else rt["value"],
                "canonical": None if not can else can["value"],
            }
        pairs.append(rec)

    conflicts = [p for p in pairs if p["conflict"]]
    only_runtime = [p for p in pairs if p["present_in"] == "runtime_pin"]
    only_canonical = [p for p in pairs if p["present_in"] == "canonical"]
    identical = [p for p in pairs if p["comparison"] == "IDENTICAL"]
    conflicts_bound = [p for p in conflicts if p["bound_runtime"]]

    counts = {
        "pairs": len(pairs),
        "identical_in_both": len(identical),
        "only_runtime_pin": len(only_runtime),
        "only_canonical": len(only_canonical),
        "conflict": len(conflicts),
        "conflicts_touching_bound_runtime": len(conflicts_bound),
    }
    dispositions = {d: 0 for d in DISPOSITIONS}
    for p in pairs:
        dispositions[p["disposition"]] = dispositions.get(p["disposition"], 0) + 1

    headline = (
        "CONFLICTS=%d. Trees diverge by disagreement, not only omission. "
        "%d of those touch a bound_runtime shape (a wrong merge changes admissions)."
        % (len(conflicts), len(conflicts_bound))
        if conflicts else
        "CONFLICTS=0. The trees diverge only by omission, never by disagreement; "
        "the eventual merge is far safer than feared."
    )
    return {
        "schema": "shape-constraint-ledger/v0",
        "nothing_merged": True,
        "nothing_deleted": True,
        "config_shape_root_untouched": True,
        "documents": docs_meta,
        "counts": counts,
        "disposition_counts": dispositions,
        "headline": headline,
        "because": (
            "A constraint in only one document is classified, never silently "
            "kept or dropped. CONFLICTS are the finding -- values are not chosen "
            "by preferring a tree. Currently enforced (runtime pin) constraints "
            "are the compatibility baseline."
        ),
        "conflicts": [
            {
                "key": p["key"],
                "profile": p["profile"],
                "shape_local": p["shape_local"],
                "path": p["path"],
                "component": p["component"],
                "how": p["how"],
                "bound_runtime": p["bound_runtime"],
                "disposition": p["disposition"],
                "conflict_resolved": p["conflict_resolved"],
            }
            for p in conflicts
        ],
        "pairs": pairs,
    }


def load_documents():
    missing = []
    extracted = []
    for doc in DOCUMENTS:
        path = ROOT / doc["rel"]
        if not path.is_file():
            missing.append(doc["rel"])
            continue
        rows, n_shapes, n_triples = extract_file(path, doc["profile"], doc["tree"])
        extracted.append((doc, rows, n_shapes, n_triples))
    return extracted, missing


def check(stored, live):
    errors = []
    live_pairs = {p["key"]: p for p in live.get("pairs", [])}
    stored_pairs = {p["key"]: p for p in stored.get("pairs", [])}
    if set(live_pairs) != set(stored_pairs):
        errors.append("pairs set mismatch live_only=%s stored_only=%s"
                      % (sorted(set(live_pairs) - set(stored_pairs))[:8],
                         sorted(set(stored_pairs) - set(live_pairs))[:8]))
    for k, row in live_pairs.items():
        got = stored_pairs.get(k)
        if not got:
            continue
        if got.get("present_in") != row["present_in"]:
            errors.append("present_in mismatch %s live=%s stored=%s"
                          % (k, row["present_in"], got.get("present_in")))
        if got.get("comparison") != row["comparison"]:
            errors.append("comparison mismatch %s live=%s stored=%s"
                          % (k, row["comparison"], got.get("comparison")))
        if got.get("disposition") not in DISPOSITIONS:
            errors.append("DISPOSITION NOT IN CLOSED SET: %s stored=%s"
                          % (k, got.get("disposition")))
        elif got.get("disposition") != row["disposition"]:
            errors.append("disposition mismatch %s live=%s stored=%s"
                          % (k, row["disposition"], got.get("disposition")))

    # THE KEY THE CHECKER READS. Plant a missing or extra conflicts[] row.
    live_c = {c["key"]: c for c in live.get("conflicts", [])}
    stored_c = {c["key"]: c for c in stored.get("conflicts", [])}
    missing_c = sorted(set(live_c) - set(stored_c))
    extra_c = sorted(set(stored_c) - set(live_c))
    if missing_c:
        errors.append("UNRESOLVED CONFLICT: live DIFFERENT missing from conflicts[]: %s"
                      % missing_c[:10])
    if extra_c:
        errors.append("UNRESOLVED CONFLICT: conflicts[] names a pair the live graph does not: %s"
                      % extra_c[:10])
    for k, row in live_c.items():
        got = stored_c.get(k)
        if not got:
            continue
        if got.get("how") != row["how"]:
            errors.append("conflicts[] how mismatch %s" % k)
        if got.get("conflict_resolved") is True:
            errors.append("CONFLICT MARKED RESOLVED WITHOUT THIS STEP'S AUTHORITY: %s" % k)
    if live["counts"] != stored.get("counts"):
        errors.append("counts mismatch live=%s stored=%s"
                      % (live["counts"], stored.get("counts")))
    return errors


def main(argv):
    write = "--write" in argv
    extracted, missing = load_documents()
    # Population is the union of (shape, constraint) pairs across the four
    # documents, not the raw per-tree row count. Compute after merge when we can;
    # if nothing loaded, the population is zero.
    if not extracted:
        populated, _pop = emit_population(0, skipped_reason="no profile-9/11 TTL documents")
        if not populated:
            return 1
        print("FAIL-CLOSED: no TTL documents under CHECK_ROOT", file=sys.stderr)
        return 1

    owners = owners_index()
    live = build_ledger(extracted, owners)
    n = live["counts"]["pairs"]
    populated, _pop = emit_population(n, skipped_reason="no (shape, constraint) pairs")
    if not populated:
        return 1

    if missing:
        print("FAIL-CLOSED: missing expected documents: %s" % missing, file=sys.stderr)
        return 1

    if write:
        LEDGER.parent.mkdir(parents=True, exist_ok=True)
        LEDGER.write_text(json.dumps(live, indent=2) + "\n")
        print("wrote", LEDGER.relative_to(ROOT) if ROOT in LEDGER.parents else LEDGER)
        print("counts", json.dumps(live["counts"]))
        print("dispositions", json.dumps(live["disposition_counts"]))
        print(live["headline"])
        return 0

    if not LEDGER.is_file():
        print("FAIL-CLOSED: missing", LEDGER, file=sys.stderr)
        return 1
    stored = json.loads(LEDGER.read_text())
    errors = check(stored, live)
    print("counts", json.dumps(live["counts"]))
    print(live["headline"])
    if errors:
        print("SHAPE CONSTRAINT LEDGER FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors[:30]:
            print("  " + e, file=sys.stderr)
        return 1
    print("shape constraint ledger: OK (%d pairs, %d identical, %d only-runtime, %d only-canonical, %d conflict)"
          % (live["counts"]["pairs"],
             live["counts"]["identical_in_both"],
             live["counts"]["only_runtime_pin"],
             live["counts"]["only_canonical"],
             live["counts"]["conflict"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
