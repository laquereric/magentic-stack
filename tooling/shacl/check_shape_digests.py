#!/usr/bin/env python3
"""Step 6: dual digest recording.

Legacy `shape_digest` is the bare SHA-256 of exact runtime-root file bytes.
It is not reinterpreted. `shape_digest_v2` is the same value with algorithm
and coverage declared on the record. `shape_artifact_id` names the compiled
Ruby backend and MUST NOT collide for two shapes that share a source file.

The key this checker reads is `entries[]` (per catalog shape). A planted
wrong `shape_digest` with unchanged bytes must fire. A planted v2 missing
`covers` must fire. Empty CHECK_ROOT fails closed.

Does not move TTL, edit shapes, or touch config.shape_root.
Does not change Grounding refusal behaviour.
"""
from __future__ import annotations
import hashlib, json, os, re, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

ROOT = Path(os.environ["CHECK_ROOT"]) if os.environ.get("CHECK_ROOT") else Path(__file__).resolve().parents[2]
STORED = ROOT / "tooling/shacl/shape_digest_baseline.json"
IDENTITY = ROOT / "tooling/shacl/shape_split_identity.json"
GROUNDING = ROOT / "gems/rails-osi-level-8/lib/rails_osi_level_8/grounding.rb"
CATALOG = ROOT / "gems/rails-osi-level-8/lib/rails_osi_level_8/profile_catalog.rb"
P9_VOCAB = ROOT / "gems/rails-osi-level-8/lib/rails_osi_level_8/profile9/vocabulary.rb"
P11_VOCAB = ROOT / "gems/rails-osi-level-8/lib/rails_osi_level_8/profile11/vocabulary.rb"
OLD_RUNTIME = ROOT / "gems/rails-osi-level-8/data/osi-level-8"

V2_REQUIRED = ("algorithm", "value", "covers")
RUNTIME_GLOBS = (
    "gems/shapes-level-8/**/*.ttl",
    "gems/shapes-application/**/*.ttl",
)
APP_MIND = "gems/shapes-application/contracts/mind-pod"


def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    h.update(p.read_bytes())
    return h.hexdigest()


def catalog_shapes():
    """shape_name -> repo-relative path, mirroring ProfileCatalog.default."""
    out = {}
    if CATALOG.is_file():
        text = CATALOG.read_text(encoding="utf-8", errors="replace")
        for m in re.finditer(
            r'"((?:P\d+::)[^"]+Shape)"\s*=>\s*\[APP,\s*"#\{APP_MIND\}/([^"]+\.ttl)"',
            text,
        ):
            out[m.group(1)] = APP_MIND + "/" + m.group(2)
        for m in re.finditer(
            r'"((?:P\d+::)[^"]+Shape)"\s*=>\s*\[L8,\s*"#\{L8_BUNDLES\}/([^"]+\.ttl)"',
            text,
        ):
            out[m.group(1)] = "gems/shapes-level-8/bundles/" + m.group(2)
    for vocab, rel in (
        (P9_VOCAB, APP_MIND + "/profile-9-ghis.ttl"),
        (P11_VOCAB, APP_MIND + "/profile-11-meaning.ttl"),
    ):
        if not vocab.is_file():
            continue
        text = vocab.read_text(encoding="utf-8", errors="replace")
        for m in re.finditer(r'(?:request_shape|response_shape):\s*"((?:P\d+::)[^"]+Shape)"', text):
            out[m.group(1)] = rel
    return out


def covers_for(rel: str) -> str:
    base = Path(rel).name
    split_from = {
        "profile-9-ghis.ttl": "gems/rails-osi-level-8/data/osi-level-8/profile-9-ghis.ttl",
        "profile-11-meaning.ttl": "gems/rails-osi-level-8/data/osi-level-8/profile-11-meaning.ttl",
    }
    if base in split_from:
        return (
            "source shape text: exact bytes of %s; previous file-level digest covered "
            "%s which no longer exists (ADR 0044); not canonicalized RDF; "
            "not the compiled Ruby backend" % (rel, split_from[base])
        )
    return (
        "source shape text: exact bytes of %s (moved byte-identical from "
        "gems/rails-osi-level-8/data/osi-level-8/%s); not canonicalized RDF; "
        "not the compiled Ruby backend" % (rel, base)
    )


def live():
    files = {}
    for g in RUNTIME_GLOBS:
        for p in sorted(ROOT.glob(g)):
            rel = p.relative_to(ROOT).as_posix() if ROOT in p.parents else p.as_posix()
            files[rel] = {"path": rel, "shape_digest": sha256_file(p)}
    compiler = sha256_file(GROUNDING) if GROUNDING.is_file() else "unsigned"
    shapes = catalog_shapes()
    entries = []
    for name in sorted(shapes):
        rel = shapes[name]
        rec = files.get(rel)
        digest = rec["shape_digest"] if rec else hashlib.sha256(rel.encode()).hexdigest()
        entries.append({
            "shape": name,
            "file": rel,
            "shape_digest": digest,
            "shape_digest_v2": {
                "algorithm": "sha256",
                "value": digest,
                "covers": covers_for(rel),
            },
            "shape_artifact_id": "shape-artifact:ruby/grounding/%s@sha256:%s" % (name, compiler),
        })
    ident = json.loads(IDENTITY.read_text()) if IDENTITY.is_file() else {}
    return {
        "schema": "shape-digest-baseline/v1",
        "legacy_shape_digest": "bare sha256 of exact file bytes; control-group files keep the pre-move digest (ADR 0044)",
        "compiler_file": "gems/rails-osi-level-8/lib/rails_osi_level_8/grounding.rb",
        "compiler_sha256": compiler,
        "file_count": len(files),
        "control_group": ident.get("control_group") or [],
        "unchanged_legacy_digest_count": len(ident.get("control_group") or []),
        "files": files,
        "entries": entries,
    }


def check(stored, live_doc):
    errors = []
    leftover = sorted(OLD_RUNTIME.glob("*.ttl")) if OLD_RUNTIME.is_dir() else []
    if leftover:
        errors.append("OLD RUNTIME ROOT STILL HAS TTL: %s"
                      % [p.name for p in leftover])
    live_files = live_doc.get("files") or {}
    stored_files = stored.get("files") or {}
    if set(live_files) != set(stored_files):
        errors.append("runtime-root file set mismatch live=%s stored=%s"
                      % (sorted(live_files), sorted(stored_files)))
    moved = []
    control_new = {c.get("new") for c in (live_doc.get("control_group") or [])}
    for name, rec in live_files.items():
        got = stored_files.get(name) or {}
        if got.get("shape_digest") != rec["shape_digest"]:
            moved.append(name)
            errors.append(
                "LEGACY DIGEST MOVED for unchanged-or-mismatched bytes: %s live=%s stored=%s"
                % (name, rec["shape_digest"], got.get("shape_digest"))
            )
    for c in live_doc.get("control_group") or []:
        rec = live_files.get(c.get("new")) or {}
        if rec.get("shape_digest") != c.get("shape_digest"):
            errors.append(
                "CONTROL GROUP DIGEST MOVED: %s live=%s pre-move=%s"
                % (c.get("file"), rec.get("shape_digest"), c.get("shape_digest"))
            )
    # Per-shape text identity across the split (ADR 0044).
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    try:
        from shape_text import extract_file
        ident = json.loads(IDENTITY.read_text()) if IDENTITY.is_file() else {}
        expected = {(s["new_file"], s["local_name"]): s for s in ident.get("shapes") or []}
        live_hash = {}
        for rel in live_files:
            p = ROOT / rel
            if not p.is_file():
                continue
            if "profile-9-ghis.ttl" not in rel and "profile-11-meaning.ttl" not in rel:
                continue
            _, blocks = extract_file(p)
            for b in blocks:
                live_hash[(rel, b["local_name"])] = b["sha256"]
        for key, rec in expected.items():
            got = live_hash.get(key)
            if not got:
                errors.append("SPLIT SHAPE MISSING AFTER CUTOVER: %s in %s" % (rec["local_name"], rec["new_file"]))
            elif got != rec["sha256"]:
                errors.append("SHAPE TEXT CHANGED DURING SPLIT: %s in %s" % (rec["local_name"], rec["new_file"]))
        n_p9 = sum(1 for s in expected.values() if "profile-9" in s.get("old_file", ""))
        if expected and n_p9 != 43:
            errors.append("P9 split identity count %d != 43" % n_p9)
    except Exception as e:
        errors.append("split identity check failed: %s" % e)
    live_e = {e["shape"]: e for e in live_doc.get("entries") or []}
    stored_e = {e["shape"]: e for e in stored.get("entries") or []}
    # THE KEY THE CHECKER READS.
    if set(live_e) != set(stored_e):
        errors.append("entries[] set mismatch live_only=%s stored_only=%s"
                      % (sorted(set(live_e) - set(stored_e))[:8],
                         sorted(set(stored_e) - set(live_e))[:8]))
    ids = []
    for shape, row in stored_e.items():
        live_row = live_e.get(shape) or {}
        v2 = row.get("shape_digest_v2")
        if not isinstance(v2, dict):
            errors.append("NO COVERAGE DECLARATION: %s shape_digest_v2 missing" % shape)
            continue
        missing_fields = [k for k in V2_REQUIRED if not str(v2.get(k) or "").strip()]
        if missing_fields:
            errors.append("NO COVERAGE DECLARATION: %s shape_digest_v2 missing %s"
                          % (shape, missing_fields))
        if v2.get("algorithm") != "sha256":
            errors.append("v2 algorithm must be sha256: %s got %s" % (shape, v2.get("algorithm")))
        if row.get("shape_digest") != live_row.get("shape_digest"):
            errors.append(
                "LEGACY DIGEST MOVED while source bytes live as %s: shape %s stored=%s live=%s"
                % (live_row.get("shape_digest"), shape, row.get("shape_digest"), live_row.get("shape_digest"))
            )
        if v2.get("value") and v2.get("value") != row.get("shape_digest"):
            errors.append("v2.value must equal legacy shape_digest for %s" % shape)
        covers = str(v2.get("covers") or "")
        rel = row.get("file") or ""
        if "profile-9-ghis.ttl" in rel or "profile-11-meaning.ttl" in rel:
            if "no longer exists" not in covers:
                errors.append("split file v2.covers must say the old digest covered a file that no longer exists: %s" % shape)
        aid = row.get("shape_artifact_id") or ""
        if not aid:
            errors.append("missing shape_artifact_id: %s" % shape)
        elif aid == row.get("shape_digest"):
            errors.append("shape_artifact_id collides with source digest: %s" % shape)
        elif shape not in aid:
            errors.append("shape_artifact_id does not name the shape: %s" % shape)
        ids.append((aid, shape))
        if live_row and aid != live_row.get("shape_artifact_id"):
            errors.append("shape_artifact_id stale for %s" % shape)
    by_id = {}
    for aid, shape in ids:
        by_id.setdefault(aid, []).append(shape)
    for aid, names in by_id.items():
        if aid and len(names) > 1:
            errors.append("shape_artifact_id collision %s -> %s" % (aid, names))
    return errors, moved


def main(argv):
    write = "--write" in argv
    doc = live()
    n = len(doc["entries"])
    populated, _pop = emit_population(n, skipped_reason="no catalog shapes / no runtime-root TTL")
    if not populated:
        return 1

    if write:
        STORED.parent.mkdir(parents=True, exist_ok=True)
        STORED.write_text(json.dumps(doc, indent=2) + "\n")
        print("wrote", STORED.relative_to(ROOT) if ROOT in STORED.parents else STORED)
        print("files", doc["file_count"], "entries", n,
              "unchanged_legacy_digest_count", doc["unchanged_legacy_digest_count"])
        return 0

    if not STORED.is_file():
        print("FAIL-CLOSED: missing", STORED, file=sys.stderr)
        return 1
    stored = json.loads(STORED.read_text())
    errors, moved = check(stored, doc)
    print("files", doc["file_count"], "entries", n,
          "unchanged_legacy_digest_count",
          len(doc.get("control_group") or []))
    if errors:
        print("SHAPE DIGEST FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors[:40]:
            print("  " + e, file=sys.stderr)
        return 1
    print("shape digests: OK (%d files, %d entries, %d control-group digests unchanged)"
          % (doc["file_count"], n, len(doc.get("control_group") or [])))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
