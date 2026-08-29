#!/usr/bin/env python3
"""Step 7: shadow manifest resolution.

ONE resolution point: shape_binding_manifest.json, extended with
source_shape / legacy_sources / generated_runtime / owner / execution /
status / compatibility_policy. Completeness is the requirement: every
NodeShape on disk must appear. A consumer must not load a TTL path the
manifest does not name.

SHADOW ONLY. config.shape_root and the runtime pin are not changed.

Keys this checker reads:
  shapes[].local_name     completeness (disk vs listed)
  named TTL paths         unnamed-path consumer load
  REQUIRED_FIELDS         a row missing a field

Does not move TTL, edit shapes, or touch config.shape_root.
Does not implement ADR 0042.
"""
from __future__ import annotations
import json, os, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parent))
from population import emit_population
from shape_resolution import (
    REQUIRED_FIELDS, COMPAT, MANIFEST_REL, DEFAULT_SCOPE, load_manifest,
    named_ttl_rels, disk_ttl_files, disk_nodeshapes, enrich_rows, sha256_file,
)

ROOT = Path(os.environ["CHECK_ROOT"]) if os.environ.get("CHECK_ROOT") else Path(__file__).resolve().parents[2]


def rel(p: Path) -> str:
    try:
        return p.relative_to(ROOT).as_posix()
    except ValueError:
        return p.as_posix()


def check(manifest):
    errors = []
    rows = manifest.get("shapes") or []
    listed = {r.get("local_name"): r for r in rows}
    disk = disk_nodeshapes(ROOT)
    missing = sorted(set(disk) - set(listed))
    extra = sorted(set(listed) - set(disk))
    if missing:
        for n in missing[:20]:
            errors.append("NODESHAPE ON DISK ABSENT FROM MANIFEST: %s" % n)
    if extra:
        errors.append("manifest names not on disk: %s" % extra[:10])
    expected = int(((manifest or {}).get("scope") or {}).get("in_scope_count") or 171)
    if listed and len(disk) != len(listed):
        errors.append("row count disk=%d manifest=%d (reconcile to in_scope_count %d)"
                      % (len(disk), len(listed), expected))
    elif listed and len(listed) != expected:
        errors.append("manifest rows %d != declared in_scope_count %d"
                      % (len(listed), expected))

    for name, row in listed.items():
        for field in REQUIRED_FIELDS:
            if field not in row or row.get(field) in ("", [], {}):
                # generated_runtime may be JSON null
                if field == "generated_runtime" and row.get(field) is None:
                    continue
                if field not in row or row.get(field) == "":
                    errors.append("MISSING REQUIRED FIELD %s: %s" % (field, name))
        pol = row.get("compatibility_policy")
        if pol not in COMPAT:
            errors.append("compatibility_policy not in closed set: %s %s" % (name, pol))

    named = set(named_ttl_rels(manifest))
    for f in disk_ttl_files(ROOT):
        r = rel(f)
        if r not in named:
            errors.append("UNNAMED PATH: consumer glob would load %s which the manifest does not name" % r)

    # Admission-equivalence findings (not smoothed): runtime-pin file digest
    # vs stored legacy digest of that file, per row.
    findings = []
    for name, row in listed.items():
        src = row.get("source_shape") or {}
        for ls in row.get("legacy_sources") or []:
            if ls.get("tree") != "runtime_pin":
                continue
            live = sha256_file(ROOT / ls["file"]) if ls.get("file") else None
            stored = ls.get("digest")
            if live and stored and live != stored:
                findings.append({
                    "shape": name,
                    "file": ls["file"],
                    "live": live,
                    "stored": stored,
                    "because": "runtime-pin digest through the manifest differs from bytes on disk",
                })
    return errors, findings, len(disk), len(listed)


def main(argv):
    write = "--write" in argv
    manifest = load_manifest(ROOT)
    disk = disk_nodeshapes(ROOT)
    n = len(disk) if disk else (len((manifest or {}).get("shapes") or []))
    populated, _pop = emit_population(n, skipped_reason="no NodeShapes on disk / no manifest")
    if not populated:
        return 1
    if manifest is None:
        print("FAIL-CLOSED: missing", ROOT / MANIFEST_REL, file=sys.stderr)
        return 1

    if write:
        rows = enrich_rows(ROOT, manifest.get("shapes") or [])
        manifest["shapes"] = rows
        manifest["scope"] = manifest.get("scope") or json.loads(json.dumps(DEFAULT_SCOPE))
        manifest["resolution"] = "shadow-v0"
        manifest["resolution_note"] = (
            "consumers load TTL paths named here; config.shape_root is unchanged; "
            "one row per NodeShape; completeness vs the in-scope trees is the gate; "
            "ontology/ and other gems are explicit exclusions (option b)"
        )
        dest = ROOT / MANIFEST_REL
        dest.write_text(json.dumps(manifest, indent=2) + "\n")
        print("wrote", dest.relative_to(ROOT) if ROOT in dest.parents else dest)
        print("rows", len(rows), "reconcile_to_171", len(rows) == 171)
        return 0

    errors, findings, n_disk, n_listed = check(manifest)
    print("disk_nodeshapes", n_disk, "manifest_rows", n_listed,
          "reconcile_to_171", n_disk == 171 and n_listed == 171)
    print("admission_equivalence_findings", len(findings))
    if findings:
        for f in findings[:10]:
            print("  FINDING", f["shape"], f["because"])
    if errors:
        print("SHAPE RESOLUTION FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors[:40]:
            print("  " + e, file=sys.stderr)
        return 1
    print("shape resolution: OK (%d NodeShapes, shadow only, completeness holds)"
          % n_listed)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
