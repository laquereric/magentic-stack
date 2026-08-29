#!/usr/bin/env python3
"""Apply the DECIDED role rule to every NodeShape. Do not relitigate it.

owner = level-8 iff the normative subject is a protocol profile or reusable
vocabulary AND validity does not depend on one app's routes / persistence /
adapter / deployment.

owner = application iff the normative subject is an app's accepted
request/response contract or an app-specific refinement.

Runtime-vs-CI binding is METADATA, not the rule.

namespace_partition is the measured starting split (review table):
  application = IRI in ux | session | meaning | osi.example  (103)
  level-8     = everything else, canonical protocol profiles (68)

LIST every shape where owner != namespace_partition. That list is the
migration risk. If empty, say so.
"""
from __future__ import annotations
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAN = json.loads((ROOT / "tooling/shacl/shape_binding_manifest.json").read_text())
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "tooling/shacl/shape_owner_candidates.json"

OP_SHAPE = re.compile(r"(Pull|Effect|Context)Shape$")


def iri_of(s):
    iris = s.get("iris") or []
    return iris[0] if iris else ""


def files_of(s):
    return " ".join(o["file"] for o in s.get("occurrences") or [])


def namespace_partition(s):
    iri = iri_of(s)
    if any(k in iri for k in ("osi8/ux", "osi8/session", "osi8/meaning", "osi.example")):
        return "application"
    return "level-8"


def owner_role(s):
    iri = iri_of(s)
    local = s["local_name"]
    files = files_of(s)

    if "osi.example" in iri:
        return ("application", "quarantine",
                "non-resolvable placeholder namespace; review §2.3 — quarantine, do not rename silently")

    if "osi8/session" in iri or local.startswith("Session"):
        return ("application", "active",
                "mind-pod session cycle (session.open/.context/.observe/.close/.latest); "
                "validity depends on this app's BACK/MIND/GRAPH operations")

    if re.search(r"P[14]Note|(^|:)Note(Create|List)", local) or (
            "NoteCreate" in local or "NoteList" in local or "DurableReceipt" in local):
        if "rails-osi-level-8/data" in files or "Note" in local:
            return ("application", "active",
                    "mind-pod Note CPCP operations / P4 receipt; depends on this app's Note model and routes")

    # Application operation contracts: request/response of THIS app's ux.* / meaning.* routes
    if OP_SHAPE.search(local) and any(k in iri for k in ("osi8/ux", "osi8/meaning")):
        return ("application", "active" if s["state"] == "bound_runtime" else "quarantined",
                "application CPCP operation contract bound (or named for) this app's routes; "
                "a second app would not reuse this request/response shape as-is")

    # Remaining meaning vocabulary (Concept, DefinitionRevision, ...)
    if "osi8/meaning" in iri:
        return ("level-8", "active" if s["state"] != "unowned" else "quarantined",
                "Profile 11 reusable meaning vocabulary; validity does not depend on one app's routes. "
                "Execution (Contract.validate!) is metadata.")

    # Remaining GHIS document/component ontology
    if "osi8/ux" in iri:
        return ("level-8", "active" if s["state"] != "unowned" else "quarantined",
                "Profile 9 GHIS reusable vocabulary (document/component ontology), not an app route. "
                "Execution is metadata.")

    # Canonical OSI L8 profiles (intent, p1–p8, …)
    return ("level-8",
            "active" if s["state"] == "bound_ci_only" else "quarantined",
            "OSI Level 8 protocol-profile shape in the canonical package; "
            "validity does not depend on one app's routes/persistence/adapter/deployment")


rows = []
disagree = []
for s in MAN["shapes"]:
    ns = namespace_partition(s)
    owner, status, because = owner_role(s)
    rec = {
        "local_name": s["local_name"],
        "iris": s.get("iris") or [],
        "occurrences": s.get("occurrences") or [],
        "execution": {"bound_runtime": "runtime", "bound_ci_only": "ci",
                      "unowned": "none", "deprecated": "none",
                      "external_binding": "none"}[s["state"]],
        "binding_state": s["state"],
        "namespace_partition": ns,
        "owner": owner,
        "status": status,
        "authority": "source",
        "agree": owner == ns,
        "because": because,
    }
    rows.append(rec)
    if not rec["agree"]:
        disagree.append({
            "local_name": rec["local_name"],
            "iri": (rec["iris"] or [""])[0],
            "namespace_partition": ns,
            "owner": owner,
            "execution": rec["execution"],
            "status": status,
            "because": because,
            "file": rec["occurrences"][0]["file"] if rec["occurrences"] else None,
            "line": rec["occurrences"][0]["line"] if rec["occurrences"] else None,
        })

n_app_ns = sum(1 for r in rows if r["namespace_partition"] == "application")
n_l8_ns = sum(1 for r in rows if r["namespace_partition"] == "level-8")
n_app_own = sum(1 for r in rows if r["owner"] == "application")
n_l8_own = sum(1 for r in rows if r["owner"] == "level-8")

doc = {
    "schema": "shape-owner-candidates/v0",
    "rule": "role, not namespace. A shape belongs in shapes-level-8 if its "
            "normative subject is an OSI Level 8 protocol profile or reusable "
            "vocabulary AND validity does not depend on one application's "
            "routes, persistence, adapter, or deployment. Else shapes-application.",
    "namespace_partition_definition": {
        "application": "IRI contains osi8/ux | osi8/session | osi8/meaning | osi.example",
        "level-8": "all other NodeShapes (canonical protocol-profile package)",
        "counts": {"application": n_app_ns, "level-8": n_l8_ns},
        "matches_review_table": n_app_ns == 103 and n_l8_ns == 68,
    },
    "owner_counts": {"application": n_app_own, "level-8": n_l8_own},
    "disagreements": {
        "count": len(disagree),
        "note": "empty means role and namespace agree everywhere. non-empty is the whole risk of this migration.",
        "shapes": disagree,
    },
    "shapes": rows,
}

OUT.write_text(json.dumps(doc, indent=2) + "\n")
print("wrote", OUT)
print("namespace", n_app_ns, "application /", n_l8_ns, "level-8")
print("owner     ", n_app_own, "application /", n_l8_own, "level-8")
print("DISAGREEMENTS", len(disagree))
for d in disagree:
    print("  %s  ns=%s owner=%s exec=%s" % (d["local_name"], d["namespace_partition"], d["owner"], d["execution"]))
