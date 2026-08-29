#!/usr/bin/env python3
"""Step 7b: explicit scope boundary.

Option (b): ontology/ and other gems are OUT of the OSI L8 profile package.
in-scope count stays 171. Every NodeShape under gems/**/*.ttl must be
either listed in the binding manifest OR named on an exclusion for its
file. A constraint-bearing NodeShape that is neither listed nor excluded
fails. A NodeShape in an excluded file that is not on that exclusion's
nodeshapes list also fails.

The boundary lives in manifest['scope']['exclusions'], not in a glob.

Does not move TTL, edit shapes, or touch config.shape_root.
"""
from __future__ import annotations
import json, os, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parent))
from population import emit_population
from shape_resolution import (
    DEFAULT_SCOPE, MANIFEST_REL, load_manifest, in_scope_path,
    sweep_gems_nodeshapes, exclusion_for,
)

ROOT = Path(os.environ["CHECK_ROOT"]) if os.environ.get("CHECK_ROOT") else Path(__file__).resolve().parents[2]


def check(manifest, hits):
    errors = []
    scope = (manifest or {}).get("scope") or {}
    exclusions = scope.get("exclusions") or []
    if not exclusions:
        errors.append("scope.exclusions missing — a glob is not a boundary")
    listed = {r.get("local_name") for r in (manifest or {}).get("shapes") or []}
    for hit in hits:
        rel, name = hit["file"], hit["local_name"]
        if in_scope_path(rel):
            if name not in listed:
                errors.append(
                    "NODESHAPE NEITHER LISTED NOR EXCLUDED: %s at %s:%s (in-scope tree)"
                    % (name, rel, hit["line"])
                )
            continue
        ex = exclusion_for(rel, exclusions)
        if ex is None:
            errors.append(
                "NODESHAPE NEITHER LISTED NOR EXCLUDED: %s at %s:%s"
                % (name, rel, hit["line"])
            )
            continue
        allowed = set(ex.get("nodeshapes") or [])
        if name not in allowed:
            errors.append(
                "EXCLUDED LOCATION NOT ON EXCLUSION LIST: %s at %s:%s (exclusion names %s)"
                % (name, rel, hit["line"], sorted(allowed))
            )
    in_scope = [h for h in hits if in_scope_path(h["file"])]
    expected = int(scope.get("in_scope_count") or 0)
    unique_in_scope = {h["local_name"] for h in in_scope}
    if expected and len(unique_in_scope) != expected:
        errors.append("in_scope unique local names %d != declared in_scope_count %d"
                      % (len(unique_in_scope), expected))
    return errors, unique_in_scope


def main(argv):
    write = "--write" in argv
    hits = sweep_gems_nodeshapes(ROOT)
    n = len(hits)
    populated, _pop = emit_population(n, skipped_reason="no NodeShapes under gems/**/*.ttl")
    if not populated:
        return 1
    manifest = load_manifest(ROOT)
    if manifest is None:
        print("FAIL-CLOSED: missing", ROOT / MANIFEST_REL, file=sys.stderr)
        return 1
    if write:
        manifest["scope"] = json.loads(json.dumps(DEFAULT_SCOPE))
        dest = ROOT / MANIFEST_REL
        dest.write_text(json.dumps(manifest, indent=2) + "\n")
        print("wrote scope into", dest)
        return 0
    errors, unique_in_scope = check(manifest, hits)
    scope = manifest.get("scope") or {}
    print("swept", n, "in_scope_unique", len(unique_in_scope),
          "declared", scope.get("in_scope_count"),
          "exclusions", len(scope.get("exclusions") or []))
    if errors:
        print("SHAPE SCOPE FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors[:40]:
            print("  " + e, file=sys.stderr)
        return 1
    print("shape scope: OK (option b; in-scope %d; exclusions explicit)"
          % len(unique_in_scope))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
