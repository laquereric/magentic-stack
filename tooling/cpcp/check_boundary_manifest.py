#!/usr/bin/env python3
"""Fail if the boundary manifest and the served methods disagree.

Row 106 (machine-checkable half). The manifest names every served method
with wire identity, direction parties, shapes, refusals, and profiles;
the code must serve exactly those methods, and every manifest entry must
resolve to a real method. No wildcard consumer role: unbuilt callers are
named as such. Ontology publication (3 classes + W3ID pledge) stays an
owner act and is fenced in the manifest's own _why.

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

MANIFEST = Path("tooling/cpcp/boundary_manifest.json")
RUBY = {
    "vault": Path("runtimes/mind-pod/app/app/controllers/vault_cpcp_controller.rb"),
    "bus": Path("runtimes/mind-pod/app/app/controllers/bus_cpcp_controller.rb"),
    "persist": Path("runtimes/mind-pod/app/app/controllers/persist_cpcp_controller.rb"),
}
MIND = Path("runtimes/mind-pod/mind/mind_seam.py")
OFFLINE = Path("gems/switchyard-offline/shared/contract.js")
FIELDS = ("operation_iri", "wire_method", "seam", "producer",
          "consumers", "params", "result", "refusals", "profiles")


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


def ruby_methods(text):
    m = re.search(r"METHODS\s*=\s*\{(.*?)\}", text, re.S)
    if not m:
        return []
    return re.findall(r'"([\w.]+)"', m.group(1))


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

    examined += 1
    try:
        manifest = json.loads((root / MANIFEST).read_text(encoding="utf-8"))
        entries = manifest.get("methods") or []
        base = manifest.get("iri_base") or ""
    except (OSError, json.JSONDecodeError) as e:
        errors.append("unreadable %s: %s" % (MANIFEST.as_posix(), e))
        entries, base = [], ""
    else:
        print("  ok %s (%d methods)" % (MANIFEST.as_posix(), len(entries)))

    code = {}
    for seam, rel in RUBY.items():
        examined += 1
        text = (root / rel).read_text(encoding="utf-8", errors="replace") if (root / rel).is_file() else ""
        if not text:
            errors.append("missing %s" % rel.as_posix())
            continue
        found = ruby_methods(text)
        if not found:
            errors.append("%s declares no METHODS" % rel.as_posix())
        code[seam] = found
    examined += 1
    mind_src = (root / MIND).read_text(encoding="utf-8", errors="replace") if (root / MIND).is_file() else ""
    m = re.search(r"METHODS\s*=\s*\((.*?)\)", mind_src, re.S) if mind_src else None
    code["mind"] = re.findall(r'"([\w.]+)"', m.group(1)) if m else []
    if not code["mind"]:
        errors.append("mind seam declares no METHODS")
    examined += 1
    off_src = (root / OFFLINE).read_text(encoding="utf-8", errors="replace") if (root / OFFLINE).is_file() else ""
    off = sorted(set(re.findall(r"'(switchyard\.[\w.]+|cpcp\.[\w.]+)'", off_src))) if off_src else []
    if not off_src:
        errors.append("missing %s" % OFFLINE.as_posix())
    code["switchyard-offline"] = off

    served = [(seam, method) for seam, methods in code.items() for method in methods]
    manifested = [(e.get("seam"), e.get("wire_method")) for e in entries]
    for seam, method in served:
        examined += 1
        if (seam, method) not in manifested:
            errors.append("served but unmanifested: %s %s" % (seam, method))
    if not any("unmanifested" in e for e in errors):
        print("  ok every served method is manifested (%d)" % len(served))
    for entry in entries:
        examined += 1
        missing = [f for f in FIELDS if not entry.get(f) and entry.get(f) != []]
        if missing:
            errors.append("manifest %s missing %s" % (entry.get("wire_method"), missing))
            continue
        if not str(entry.get("operation_iri", "")).startswith(base):
            errors.append("manifest %s IRI outside iri_base" % entry.get("wire_method"))
        if any(str(c).strip().lower() in ("any", "all", "*", "anyone") for c in (entry.get("consumers") or [])):
            errors.append("manifest %s names a wildcard consumer" % entry.get("wire_method"))
        if (entry.get("seam"), entry.get("wire_method")) not in served:
            errors.append("manifest names unserved method: %s %s" % (entry.get("seam"), entry.get("wire_method")))
    if entries and not any("unserved" in e or "missing" in e or "IRI" in e or "wildcard" in e for e in errors):
        print("  ok every manifest entry resolves (%d)" % len(entries))

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("BOUNDARY MANIFEST FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("boundary manifest: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
