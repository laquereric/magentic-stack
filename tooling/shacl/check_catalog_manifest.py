#!/usr/bin/env python3
"""Fail when ProfileCatalog and the binding manifest disagree about a gem.

Gap 66. The live resolver is ProfileCatalog. The manifest names source_shape
+ execution. They must agree: every execution=runtime source file the
manifest names must be a catalog resolution target, and every catalog
target that matches a manifest local_name must be that source_shape file.

Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

CATALOG = Path("gems/rails-osi-level-8/lib/rails_osi_level_8/profile_catalog.rb")
MANIFEST = Path("tooling/shacl/shape_binding_manifest.json")
APP_RE = re.compile(
    r'"((?:P\d+::)[^"]+Shape)"\s*=>\s*\[APP,\s*"#\{APP_MIND\}/([^"]+\.ttl)"'
)
L8_RE = re.compile(
    r'"((?:P\d+::)[^"]+Shape)"\s*=>\s*\[L8,\s*"#\{L8_BUNDLES\}/([^"]+\.ttl)"'
)


def fail_empty_check_root():
    if "CHECK_ROOT" in os.environ and not str(os.environ.get("CHECK_ROOT", "")).strip():
        print("FAIL: empty CHECK_ROOT", file=sys.stderr)
        return True
    return False


def root_from_env():
    raw = os.environ.get("CHECK_ROOT")
    if raw is None:
        return Path(__file__).resolve().parents[2]
    return Path(raw)


def catalog_targets(text: str):
    out = {}
    for m in APP_RE.finditer(text):
        out[m.group(1)] = "gems/shapes-application/contracts/mind-pod/" + m.group(2)
    for m in L8_RE.finditer(text):
        out[m.group(1)] = "gems/shapes-level-8/bundles/" + m.group(2)
    return out


def local_name(catalog_key: str) -> str:
    return catalog_key.split("::", 1)[-1]


def main():
    if fail_empty_check_root():
        return 1
    root = root_from_env()
    if not root.is_dir():
        print("FAIL: CHECK_ROOT is not a directory: %s" % root, file=sys.stderr)
        return 1
    try:
        nonempty = any(root.iterdir())
    except OSError as e:
        print("FAIL: CHECK_ROOT unreadable: %s" % e, file=sys.stderr)
        return 1
    if not nonempty:
        print("FAIL: empty CHECK_ROOT tree", file=sys.stderr)
        return 1

    errors = []
    examined = 0

    cat_path = root / CATALOG
    man_path = root / MANIFEST
    examined += 1
    if not cat_path.is_file():
        errors.append("missing %s" % CATALOG.as_posix())
        text = ""
    else:
        text = cat_path.read_text(encoding="utf-8", errors="replace")
        print("  ok %s" % CATALOG.as_posix())

    examined += 1
    if "L8 = " not in text or "L8_PROTOCOL_MAP" not in text:
        errors.append("catalog does not declare/use L8_PROTOCOL_MAP")
    else:
        print("  ok catalog has L8_PROTOCOL_MAP")

    targets = catalog_targets(text)
    examined += 1
    l8_hits = [p for p in targets.values() if p.startswith("gems/shapes-level-8/")]
    if not l8_hits:
        errors.append("catalog resolves no shapes-level-8 file (L8 unused)")
    else:
        print("  ok catalog resolves %d names onto L8 (%s)" % (
            len(l8_hits), sorted(set(l8_hits))))

    examined += 1
    if not man_path.is_file():
        errors.append("missing %s" % MANIFEST.as_posix())
        shapes = []
    else:
        man = json.loads(man_path.read_text(encoding="utf-8"))
        shapes = man.get("shapes") or []
        print("  ok %s (%d rows)" % (MANIFEST.as_posix(), len(shapes)))

    by_local = {s.get("local_name"): s for s in shapes}
    runtime_src = []
    for s in shapes:
        if s.get("execution") != "runtime":
            continue
        src = ((s.get("source_shape") or {}).get("file") or "").strip()
        if src.startswith("gems/shapes-level-8/"):
            runtime_src.append((s.get("local_name"), src))

    examined += len(runtime_src) or 1
    catalog_by_local = {}
    for key, path in targets.items():
        catalog_by_local.setdefault(local_name(key), []).append((key, path))

    for name, src in runtime_src:
        hits = catalog_by_local.get(name) or []
        if not hits:
            errors.append("manifest execution=runtime %s source=%s has no catalog entry" % (name, src))
            continue
        paths = {p for _, p in hits}
        if src not in paths:
            errors.append("catalog %s resolves %s, manifest source_shape is %s" % (name, sorted(paths), src))
        else:
            print("  ok %s -> %s" % (name, src))

    ok_pop, _rec = emit_population(examined, skipped=0, skipped_reason="")
    if not ok_pop:
        return 1
    if errors:
        print("CATALOG MANIFEST FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors[:40]:
            print("  " + e, file=sys.stderr)
        return 1
    print("catalog-manifest: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
