#!/usr/bin/env python3
"""Every Dockerfile in this repo is declared published or not published.

ADR 0063 says the substrate publishes base images. The declaration lives in
published_images.json; this holds it to the tree BOTH WAYS:

  every published/not_published entry names a Dockerfile that exists
  every Dockerfile in the tree appears in exactly one of the two lists

A Dockerfile in neither is UNDECLARED and fails. That is the point: a new
image must be a decision, not an omission. Vendored trees are excluded the
same way check_base_digests excludes them -- from .gitmodules paths and
declared vendor prefixes, never a path literal in this source.

Empty CHECK_ROOT fails closed.
"""
import json
import os
import sys

ROOT = os.environ.get("CHECK_ROOT") or os.path.dirname(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
)
LEDGER = os.path.join(ROOT, "tooling/pins/published_images.json")


def fail(msg):
    print("PUBLISHED-IMAGES FAIL: %s" % msg, file=sys.stderr)
    return 1


def submodule_paths(root):
    """Follow-them trees, read from .gitmodules rather than hardcoded."""
    out = []
    gm = os.path.join(root, ".gitmodules")
    if os.path.isfile(gm):
        for line in open(gm, encoding="utf-8"):
            line = line.strip()
            if line.startswith("path"):
                out.append(line.split("=", 1)[1].strip())
    return out


def main():
    if not os.environ.get("CHECK_ROOT", ROOT).strip():
        return fail("empty CHECK_ROOT")
    if not os.path.isdir(ROOT):
        return fail("CHECK_ROOT is not a directory: %s" % ROOT)
    if not os.path.isfile(LEDGER):
        return fail("missing ledger %s" % LEDGER)

    try:
        led = json.load(open(LEDGER, encoding="utf-8"))
    except Exception as exc:
        return fail("ledger does not parse: %s" % exc)

    excl = list(submodule_paths(ROOT))
    # Directory names to skip come from the ledger as DATA, never as a literal
    # here. The trees they name are gitignored: present in a working clone,
    # absent in a clean checkout. Walking them would give this gate two
    # populations and a failure that only reproduces on one of them.
    skip_dirs = list(led.get("scan_exclude_dirnames") or [])
    if not skip_dirs:
        return fail("ledger declares no scan_exclude_dirnames")

    def excluded(rel):
        return any(rel.startswith(p + "/") or rel == p for p in excl)

    found = []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in skip_dirs]
        for fn in filenames:
            if fn == "Dockerfile" or fn.startswith("Dockerfile."):
                rel = os.path.relpath(os.path.join(dirpath, fn), ROOT)
                found.append(rel)

    if not found:
        return fail("empty CHECK_ROOT tree: no Dockerfile found")

    pub = {e["dockerfile"]: e for e in led.get("published", [])}
    nop = {e["dockerfile"]: e for e in led.get("not_published", [])}
    errors = []

    overlap = set(pub) & set(nop)
    if overlap:
        errors.append("declared both published and not_published: %s" % sorted(overlap))

    for path, entry in pub.items():
        if not os.path.isfile(os.path.join(ROOT, path)):
            errors.append("published entry names a missing Dockerfile: %s" % path)
        for field in ("name", "context", "because"):
            if not str(entry.get(field) or "").strip():
                errors.append("published %s missing %s" % (path, field))
    for path, entry in nop.items():
        if not os.path.isfile(os.path.join(ROOT, path)):
            errors.append("not_published entry names a missing Dockerfile: %s" % path)
        if not str(entry.get("because") or "").strip():
            errors.append("not_published %s missing because" % path)

    names = [e.get("name") for e in led.get("published", [])]
    if len(names) != len(set(names)):
        errors.append("duplicate published image name: %s" % names)

    if str(led.get("tagging", {}).get("rule", "")).find("sha-") == -1:
        errors.append("tagging.rule must pin by commit SHA")

    examined = skipped = 0
    for rel in sorted(found):
        if excluded(rel):
            skipped += 1
            continue
        examined += 1
        if rel not in pub and rel not in nop:
            errors.append("undeclared Dockerfile: %s" % rel)

    print("population: %d examined, %d skipped (follow-them / vendored)" % (examined, skipped))
    print("published: %s" % ", ".join(names))
    if errors:
        print("PUBLISHED-IMAGES FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("published images: OK (%d published, %d declared not published)"
          % (len(pub), len(nop)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
