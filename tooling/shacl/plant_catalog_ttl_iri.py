#!/usr/bin/env python3
"""Prove check_catalog_ttl_iri.py fails both ways and on empty CHECK_ROOT.

Plants:
  1. catalog IRI change that keeps the local name
  2. TTL @prefix change that keeps local names
  3. empty CHECK_ROOT
Does not leave files behind. Does not rename osi.example in the tree.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/shacl/check_catalog_ttl_iri.py"

COPY_PATHS = (
    Path("gems/rails-osi-level-8/lib/rails_osi_level_8/profile_catalog.rb"),
    Path("gems/rails-osi-level-8/lib/rails_osi_level_8/profile9/vocabulary.rb"),
    Path("gems/rails-osi-level-8/lib/rails_osi_level_8/profile11/vocabulary.rb"),
)
COPY_TREES = (
    Path("gems/shapes-application/contracts/mind-pod"),
    Path("gems/shapes-level-8/bundles"),
)

OLD_IRI = "https://osi.example/shapes/P1NoteCreateEffectShape"
NEW_IRI = "https://example.invalid/shapes/P1NoteCreateEffectShape"
OLD_PREFIX = "@prefix osi:  <https://osi.example/shapes/> ."
NEW_PREFIX = "@prefix osi:  <https://example.invalid/shapes/> ."
P1_TTL = Path("gems/shapes-application/contracts/mind-pod/profile-1-cyborg-channel.ttl")


def run(env, cwd=None):
    return subprocess.run(
        [sys.executable, str(CHECKER)],
        cwd=str(cwd or ROOT),
        env=env,
        capture_output=True,
        text=True,
    )


def copy_tree(tmp: Path):
    for rel in COPY_PATHS:
        dest = tmp / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / rel, dest)
    for rel in COPY_TREES:
        src = ROOT / rel
        dest = tmp / rel
        if dest.exists():
            shutil.rmtree(dest)
        shutil.copytree(src, dest)


def main():
    rows = []
    ok = True
    env = os.environ.copy()
    env.pop("CHECK_ROOT", None)

    r = run(env)
    rows.append(("clean", r.returncode == 0, "exit %d\n%s" % (r.returncode, r.stdout[-400:])))
    ok = ok and r.returncode == 0

    env_empty = env.copy()
    env_empty["CHECK_ROOT"] = ""
    r = run(env_empty)
    rows.append(("empty-CHECK_ROOT-fails", r.returncode != 0,
                 "exit %d %s" % (r.returncode, r.stderr.strip()[:200])))
    ok = ok and r.returncode != 0

    with tempfile.TemporaryDirectory(prefix="gap98-") as tmp:
        tmp = Path(tmp)
        env_empty_tree = env.copy()
        env_empty_tree["CHECK_ROOT"] = str(tmp)
        r = run(env_empty_tree)
        rows.append(("empty-tree-fails", r.returncode != 0,
                     "exit %d %s" % (r.returncode, r.stderr.strip()[:200])))
        ok = ok and r.returncode != 0

    with tempfile.TemporaryDirectory(prefix="gap98-cat-") as tmp:
        tmp = Path(tmp)
        copy_tree(tmp)
        catalog = tmp / COPY_PATHS[0]
        text = catalog.read_text(encoding="utf-8")
        planted = text.replace(OLD_IRI, NEW_IRI, 1)
        if planted == text:
            rows.append(("catalog-iri-plant-edit", False, "catalog did not contain %s" % OLD_IRI))
            ok = False
        else:
            catalog.write_text(planted, encoding="utf-8")
            env_plant = env.copy()
            env_plant["CHECK_ROOT"] = str(tmp)
            r = run(env_plant)
            detail = "exit %d\n%s%s" % (r.returncode, r.stdout[-200:], r.stderr[-400:])
            hit = "IRI DIVERGENCE" in (r.stderr or "") and "P1::NoteCreateEffectShape" in (r.stderr or "")
            rows.append(("catalog-iri-keeps-local-fails", r.returncode != 0 and hit, detail))
            ok = ok and r.returncode != 0 and hit

    with tempfile.TemporaryDirectory(prefix="gap98-pfx-") as tmp:
        tmp = Path(tmp)
        copy_tree(tmp)
        ttl = tmp / P1_TTL
        text = ttl.read_text(encoding="utf-8")
        planted = text.replace(OLD_PREFIX, NEW_PREFIX, 1)
        if planted == text:
            rows.append(("prefix-plant-edit", False, "TTL did not contain %s" % OLD_PREFIX))
            ok = False
        else:
            ttl.write_text(planted, encoding="utf-8")
            env_plant = env.copy()
            env_plant["CHECK_ROOT"] = str(tmp)
            r = run(env_plant)
            detail = "exit %d\n%s%s" % (r.returncode, r.stdout[-200:], r.stderr[-400:])
            hit = "IRI DIVERGENCE" in (r.stderr or "") and "local name" in (r.stderr or "")
            rows.append(("prefix-keeps-local-fails", r.returncode != 0 and hit, detail))
            ok = ok and r.returncode != 0 and hit

    print("PLANT TABLE")
    for name, passed, detail in rows:
        print("  %s  %s: %s" % ("OK " if passed else "FAIL", name, detail.strip()[:280]))
    print("plant catalog-ttl-iri: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
