#!/usr/bin/env python3
"""IRI namespace detector.

Compares FULL expanded IRIs, not local names. Binding keys by local_name
and drift canonicalises note:title to title, so a namespace change that
leaves every local name untouched currently slips through. This checker
fails that case.

Covers:
  1. ProfileCatalog SHAPE_MAP IRI literals (the 6 osi.example plus the
     session w3id IRIs written next to them)
  2. @prefix declarations in every in-scope TTL
  3. binding-manifest shapes[].iris[]

A planted @prefix IRI change must NAME the prefix and the file.
Empty CHECK_ROOT fails closed.

Does not rename any IRI. Does not edit TTL or the catalog.
"""
from __future__ import annotations
import json, os, re, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parent))
from population import emit_population
from shape_resolution import IN_SCOPE_GLOBS, load_manifest

ROOT = Path(os.environ["CHECK_ROOT"]) if os.environ.get("CHECK_ROOT") else Path(__file__).resolve().parents[2]
STORED = ROOT / "tooling/shacl/iri_namespace_baseline.json"
CATALOG = ROOT / "gems/rails-osi-level-8/lib/rails_osi_level_8/profile_catalog.rb"
MANIFEST = ROOT / "tooling/shacl/shape_binding_manifest.json"

PREFIX_RX = re.compile(r"^@prefix\s+([A-Za-z0-9_]+):\s*<([^>]+)>", re.M)
CATALOG_RX = re.compile(
    r'"((?:P\d+::)[^"]+Shape)"\s*=>\s*\[[^\]]*?,\s*"(https://[^"]+)"\s*\]',
    re.S,
)
COVERS = (
    "full expanded IRIs, not local names. (1) ProfileCatalog SHAPE_MAP "
    "IRI literals; (2) @prefix namespace IRIs in in-scope TTL "
    "(profile-*/shapes/*.ttl, shapes-level-8/**/*.ttl, "
    "shapes-application/**/*.ttl); (3) shape_binding_manifest.json "
    "shapes[].iris[]. A namespace change with identical local names must fail."
)


def rel(p: Path) -> str:
    try:
        return p.relative_to(ROOT).as_posix()
    except ValueError:
        return p.as_posix()


def catalog_iris():
    out = []
    if not CATALOG.is_file():
        return out
    text = CATALOG.read_text(encoding="utf-8", errors="replace")
    for m in CATALOG_RX.finditer(text):
        line = text[: m.start()].count("\n") + 1
        out.append({
            "shape": m.group(1),
            "iri": m.group(2),
            "file": rel(CATALOG),
            "line": line,
        })
    out.sort(key=lambda r: (r["file"], r["line"], r["shape"]))
    return out


def prefix_iris():
    out = []
    for g in IN_SCOPE_GLOBS:
        for p in sorted(ROOT.glob(g)):
            if not p.is_file():
                continue
            text = p.read_text(encoding="utf-8", errors="replace")
            r = rel(p)
            for m in PREFIX_RX.finditer(text):
                line = text[: m.start()].count("\n") + 1
                out.append({
                    "file": r,
                    "line": line,
                    "prefix": m.group(1),
                    "iri": m.group(2),
                })
    out.sort(key=lambda r: (r["file"], r["line"], r["prefix"]))
    return out


def manifest_iris():
    out = []
    man = load_manifest(ROOT)
    if not man:
        return out
    for row in man.get("shapes") or []:
        name = row.get("local_name")
        for iri in row.get("iris") or []:
            if iri:
                out.append({"local_name": name, "iri": iri})
    out.sort(key=lambda r: (r["local_name"] or "", r["iri"]))
    return out


def live():
    catalog = catalog_iris()
    prefixes = prefix_iris()
    manifest = manifest_iris()
    namespaces = sorted({
        *(r["iri"] for r in prefixes),
        *(r["iri"].rsplit("/", 1)[0] + "/" for r in catalog if "/" in r["iri"]),
    })
    return {
        "schema": "iri-namespace-baseline/v0",
        "covers": COVERS,
        "catalog": catalog,
        "prefixes": prefixes,
        "manifest_iris": manifest,
        "namespace_count": len({r["iri"] for r in prefixes}),
        "catalog_count": len(catalog),
        "manifest_iri_count": len(manifest),
        "prefix_count": len(prefixes),
    }


def key_catalog(rows):
    return {r["shape"]: r for r in rows}


def key_prefix(rows):
    return {(r["file"], r["prefix"]): r for r in rows}


def key_manifest(rows):
    return {(r["local_name"], r["iri"]) for r in rows}


def check(stored, live_doc):
    errors = []
    if not isinstance(stored.get("covers"), str) or not stored.get("covers").strip():
        errors.append("NO COVERAGE DECLARATION: baseline covers missing")
    sc, lc = key_catalog(stored.get("catalog") or []), key_catalog(live_doc.get("catalog") or [])
    for shape in sorted(set(sc) | set(lc)):
        s, l = sc.get(shape), lc.get(shape)
        if s and l and s.get("iri") != l.get("iri"):
            errors.append(
                "CATALOG IRI CHANGED shape=%s stored=%s live=%s"
                % (shape, s.get("iri"), l.get("iri"))
            )
        elif s and not l:
            errors.append("CATALOG IRI MISSING shape=%s iri=%s" % (shape, s.get("iri")))
        elif l and not s:
            errors.append("CATALOG IRI UNRECORDED shape=%s iri=%s" % (shape, l.get("iri")))
    sp, lp = key_prefix(stored.get("prefixes") or []), key_prefix(live_doc.get("prefixes") or [])
    for k in sorted(set(sp) | set(lp)):
        s, l = sp.get(k), lp.get(k)
        file, prefix = k
        if s and l and s.get("iri") != l.get("iri"):
            errors.append(
                "PREFIX NAMESPACE CHANGED prefix=%s file=%s stored=%s live=%s"
                % (prefix, file, s.get("iri"), l.get("iri"))
            )
        elif s and not l:
            errors.append("PREFIX MISSING prefix=%s file=%s iri=%s"
                          % (prefix, file, s.get("iri")))
        elif l and not s:
            errors.append("PREFIX UNRECORDED prefix=%s file=%s iri=%s"
                          % (prefix, file, l.get("iri")))
    sm, lm = key_manifest(stored.get("manifest_iris") or []), key_manifest(live_doc.get("manifest_iris") or [])
    for local, iri in sorted(lm - sm):
        errors.append("MANIFEST IRI UNRECORDED local_name=%s iri=%s" % (local, iri))
    for local, iri in sorted(sm - lm):
        errors.append("MANIFEST IRI CHANGED OR MISSING local_name=%s iri=%s" % (local, iri))
    return errors


def main(argv):
    write = "--write" in argv
    doc = live()
    n = doc["prefix_count"] + doc["catalog_count"] + doc["manifest_iri_count"]
    populated, _pop = emit_population(
        n, skipped_reason="no catalog IRIs / no in-scope @prefix / no manifest iris[]"
    )
    if not populated:
        return 1

    if write:
        STORED.parent.mkdir(parents=True, exist_ok=True)
        STORED.write_text(json.dumps(doc, indent=2) + "\n")
        print("wrote", STORED.relative_to(ROOT) if ROOT in STORED.parents else STORED)
        print("prefixes", doc["prefix_count"], "catalog", doc["catalog_count"],
              "manifest_iris", doc["manifest_iri_count"],
              "prefix_namespaces", doc["namespace_count"])
        return 0

    if not STORED.is_file():
        print("FAIL-CLOSED: missing", STORED, file=sys.stderr)
        return 1
    stored = json.loads(STORED.read_text())
    errors = check(stored, doc)
    print("prefixes", doc["prefix_count"], "catalog", doc["catalog_count"],
          "manifest_iris", doc["manifest_iri_count"],
          "prefix_namespaces", doc["namespace_count"])
    if errors:
        print("IRI NAMESPACE FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors[:40]:
            print("  " + e, file=sys.stderr)
        return 1
    print("iri namespaces: OK (%d prefixes, %d catalog IRIs, %d manifest iris, %d prefix namespaces)"
          % (doc["prefix_count"], doc["catalog_count"],
             doc["manifest_iri_count"], doc["namespace_count"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
