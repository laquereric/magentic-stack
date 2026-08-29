#!/usr/bin/env python3
"""Shadow resolution: consumers load TTL paths the binding manifest names.

ONE resolution point: tooling/shacl/shape_binding_manifest.json.
This module does not glob. Discovery-of-unlisted-files is the resolution
checker's job, not a consumer's.
"""
from __future__ import annotations
import fnmatch, hashlib, json, re
from pathlib import Path

MANIFEST_REL = Path("tooling/shacl/shape_binding_manifest.json")
REQUIRED_FIELDS = (
    "source_shape",
    "legacy_sources",
    "generated_runtime",
    "owner",
    "execution",
    "status",
    "compatibility_policy",
)
COMPAT = ("equivalent", "intentionally_changed", "unresolved")
CANON_GLOB = "gems/osi-level-8-profiles/profile-*/shapes/*.ttl"
RUNTIME_GLOB = "gems/rails-osi-level-8/data/osi-level-8/*.ttl"
IN_SCOPE_GLOBS = (CANON_GLOB, RUNTIME_GLOB)

# Option (b): ontology/ and other gems are OUT of the OSI L8 profile package.
# A NodeShape in an excluded location that is not on that exclusion's
# nodeshapes list is a gate failure — the boundary is the list, not the glob.
DEFAULT_SCOPE = {
    "decision": "b",
    "in_scope_globs": list(IN_SCOPE_GLOBS),
    "in_scope_count": 171,
    "because": (
        "The OSI Level 8 profile package is profile-*/shapes/*.ttl plus the "
        "runtime pin under rails-osi-level-8/data/osi-level-8. ontology/ files "
        "are PS1 vocabulary documents; some duplicate shapes/ copies, and "
        "CIDShape exists only there. mmg-acia and mmg-graph are other gems."
    ),
    "exclusions": [
        {
            "path": "gems/osi-level-8-profiles/profile-1-cyborg-channel/ontology/ps1-p1.ttl",
            "reason": "PS1-P1 ontology. Profile SHACL is shapes/ps1-p1.shacl.ttl (EnvelopeShape, NoteShape). CIDShape is ontology-only and is not loaded by Gate 2 or config.shape_root.",
            "nodeshapes": ["EnvelopeShape", "NoteShape", "CIDShape"],
        },
        {
            "path": "gems/osi-level-8-profiles/profile-2-reference-passing/ontology/ps1-p2.ttl",
            "reason": "PS1-P2 ontology. Profile SHACL is shapes/ps1-p2.shacl.ttl (EnvelopeShape, PreviewShape, InsightShape).",
            "nodeshapes": ["EnvelopeShape", "PreviewShape", "InsightShape"],
        },
        {
            "glob": "gems/mmg-acia/**/*.ttl",
            "reason": "ACIA widget shapes; not the OSI Level 8 profile package.",
            "nodeshapes": [
                "ButtonShape", "HeadingShape", "TabListShape", "TabShape",
                "ToggleShape", "StrictImageShape", "SltDimensionsShape",
            ],
        },
        {
            "glob": "gems/mmg-graph/**/*.ttl",
            "reason": "graph-db request shapes; not the OSI Level 8 profile package.",
            "nodeshapes": [
                "PublishRequest", "QueryRequest", "UpdateRequest",
                "FederateRequest", "GraphDbShape",
            ],
        },
    ],
}

UNRESOLVED_WRAP = {
    "NoteCreateEffectShape", "NoteListPullShape", "SessionObserveEffectShape",
    "P1NoteCreateEffectShape", "P1NoteListPullShape",
}
UNRESOLVED_IGNORED = {
    "AciaDocumentShape", "ComponentShape", "DesignTokenSetShape",
    "DesignTokenShape", "FlowShape", "InteractionEventShape",
    "JourneyShape", "PageShape", "TouchpointShape",
}


def sha256_file(p: Path) -> str | None:
    if not p.is_file():
        return None
    h = hashlib.sha256()
    h.update(p.read_bytes())
    return h.hexdigest()


def load_manifest(root: Path):
    path = root / MANIFEST_REL
    if not path.is_file():
        return None
    return json.loads(path.read_text())


def named_ttl_rels(manifest) -> list[str]:
    seen = []
    got = set()
    for row in (manifest or {}).get("shapes") or []:
        files = []
        src = row.get("source_shape") or {}
        if isinstance(src, dict) and src.get("file"):
            files.append(src["file"])
        for ls in row.get("legacy_sources") or []:
            if isinstance(ls, dict) and ls.get("file"):
                files.append(ls["file"])
        for o in row.get("occurrences") or []:
            if o.get("file"):
                files.append(o["file"])
        for f in files:
            if f not in got:
                got.add(f)
                seen.append(f)
    return seen


def named_ttl_files(root: Path, manifest=None) -> list[Path]:
    if manifest is None:
        manifest = load_manifest(root)
    if not manifest:
        return []
    out = []
    for rel in named_ttl_rels(manifest):
        p = root / rel
        if p.is_file():
            out.append(p)
    return sorted(out, key=lambda p: p.as_posix())


def disk_ttl_files(root: Path) -> list[Path]:
    return sorted(root.glob(CANON_GLOB)) + sorted(root.glob(RUNTIME_GLOB))


def in_scope_path(rel: str) -> bool:
    return any(fnmatch.fnmatch(rel, g) for g in IN_SCOPE_GLOBS)


def sweep_gems_nodeshapes(root: Path) -> list[dict]:
    """Every sh:NodeShape under gems/**/*.ttl. Discovery, not a consumer load."""
    hits = []
    gems = root / "gems"
    if not gems.is_dir():
        return hits
    for p in gems.rglob("*.ttl"):
        if ".git" in p.parts:
            continue
        try:
            rel = p.relative_to(root).as_posix()
        except ValueError:
            continue
        try:
            text = p.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for n, line in enumerate(text.splitlines(), 1):
            m = re.search(r"(\S+)\s+a\s+sh:NodeShape\b", line)
            if not m:
                continue
            token = m.group(1)
            local = token.rstrip("/").split("#")[-1].split("/")[-1]
            if ":" in local:
                local = local.split(":", 1)[-1]
            hits.append({"local_name": local, "file": rel, "line": n})
    return hits


def exclusion_for(rel: str, exclusions: list):
    for ex in exclusions:
        if ex.get("path") == rel:
            return ex
        g = ex.get("glob")
        if g and fnmatch.fnmatch(rel, g):
            return ex
    return None


def disk_nodeshapes(root: Path) -> dict:
    """local_name -> occurrences. Discovery glob; not a consumer load."""
    by_name = {}
    for f in disk_ttl_files(root):
        text = f.read_text(encoding="utf-8", errors="replace")
        try:
            rel = f.relative_to(root).as_posix()
        except ValueError:
            rel = f.as_posix()
        tree = "canonical" if "/osi-level-8-profiles/" in f.as_posix() else "runtime_pin"
        for n, line in enumerate(text.splitlines(), 1):
            m = re.search(r"(\S+)\s+a\s+sh:NodeShape\b", line)
            if not m:
                continue
            token = m.group(1)
            local = token.rstrip("/").split("#")[-1].split("/")[-1]
            if ":" in local:
                local = local.split(":", 1)[-1]
            rec = by_name.setdefault(local, {"occurrences": []})
            rec["occurrences"].append({"file": rel, "line": n, "tree": tree})
    return by_name


def _file_rec(root: Path, rel: str, tree: str):
    digest = sha256_file(root / rel)
    return {"file": rel, "digest": digest, "tree": tree}


def enrich_rows(root: Path, rows: list) -> list:
    owners = {}
    op = root / "tooling/shacl/shape_owner_candidates.json"
    if op.is_file():
        owners = {r["local_name"]: r for r in json.loads(op.read_text()).get("shapes") or []}
    qdec = {}
    qp = root / "tooling/shacl/shape_quarantine_inventory.json"
    if qp.is_file():
        inv = json.loads(qp.read_text())
        for r in (inv.get("unowned") or []) + (inv.get("shapes") or []):
            if r.get("local_name") and r.get("decision"):
                qdec[r["local_name"]] = r
    grounding = root / "gems/rails-osi-level-8/lib/rails_osi_level_8/grounding.rb"
    gdig = sha256_file(grounding)
    unresolved = set(UNRESOLVED_WRAP) | set(UNRESOLVED_IGNORED)
    lp = root / "tooling/shacl/shape_constraint_ledger.json"
    if lp.is_file():
        for c in json.loads(lp.read_text()).get("conflicts") or []:
            if c.get("shape_local"):
                unresolved.add(c["shape_local"])
    rp = root / "tooling/shacl/shape_runtime_artifact.json"
    if rp.is_file():
        for d in json.loads(rp.read_text()).get("divergences") or []:
            raw = (d.get("shape") or "").split("::")[-1]
            if raw:
                unresolved.add(raw)

    out = []
    for row in rows:
        local = row["local_name"]
        own = owners.get(local) or {}
        occ = list(row.get("occurrences") or [])
        legacy = [_file_rec(root, o["file"], o.get("tree") or "unknown") for o in occ]
        runtime = next((x for x in legacy if x["tree"] == "runtime_pin"), None)
        canonical = next((x for x in legacy if x["tree"] == "canonical"), None)
        execu = own.get("execution") or (
            "runtime" if row.get("state") == "bound_runtime" else
            "ci" if row.get("state") == "bound_ci_only" else "none"
        )
        if execu == "runtime" and runtime:
            source = dict(runtime)
        elif canonical:
            source = dict(canonical)
        else:
            source = dict(legacy[0]) if legacy else {"file": None, "digest": None, "tree": None}
        status = own.get("status") or (
            "quarantined" if row.get("state") == "unowned" else "active"
        )
        q = qdec.get(local)
        if q and q.get("decision") == "retain":
            status = "quarantined"
        gen = None
        if execu == "runtime":
            gen = {
                "file": "gems/rails-osi-level-8/lib/rails_osi_level_8/grounding.rb",
                "digest": gdig,
                "backend": "ruby",
            }
        policy = "unresolved" if local in unresolved else "equivalent"
        enriched = dict(row)
        enriched["source_shape"] = source
        enriched["legacy_sources"] = legacy
        enriched["generated_runtime"] = gen
        enriched["owner"] = own.get("owner") or (
            "application" if execu == "runtime" else "level-8"
        )
        enriched["execution"] = execu
        enriched["status"] = status
        enriched["compatibility_policy"] = policy
        if q and q.get("decision"):
            enriched["decision"] = q["decision"]
            enriched["decision_adr"] = q.get("decision_adr")
        out.append(enriched)
    return out
