#!/usr/bin/env python3
"""Plants for check_no_story_in_substrate_cpcp. One plant per watched file."""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/boundary/check_no_story_in_substrate_cpcp.py"
MANIFESTS = (
    ROOT / "tooling/cpcp/boundary_manifest.json",
    ROOT / "tooling/cpcp/seam_authority.json",
    ROOT / "tooling/cpcp/cpcp_callers.json",
    ROOT / "tooling/linkml/sources.json",
)


def run():
    env = os.environ.copy()
    env.pop("CHECK_ROOT", None)
    return subprocess.run(
        [sys.executable, str(CHECKER)], cwd=str(ROOT), env=env,
        capture_output=True, text=True, timeout=120,
    )


def plant_text(rows, name, path, needle, insert):
    orig = path.read_text(encoding="utf-8")
    try:
        if needle not in orig:
            rows.append((name, False, "could not plant -- needle gone in %s" % path.name))
            return False
        path.write_text(orig.replace(needle, insert + needle, 1), encoding="utf-8")
        r = run()
        rows.append((name, r.returncode != 0, "exit %d" % r.returncode))
        return r.returncode != 0
    finally:
        path.write_text(orig, encoding="utf-8")


def plant_json_key(rows, name, path, key, value):
    orig = path.read_text(encoding="utf-8")
    try:
        data = json.loads(orig)
        data[key] = value
        path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        r = run()
        rows.append((name, r.returncode != 0, "exit %d" % r.returncode))
        return r.returncode != 0
    finally:
        path.write_text(orig, encoding="utf-8")


def main() -> int:
    rows: list[tuple[str, bool, str]] = []
    ok = True

    r = run()
    rows.append(("clean", r.returncode == 0, "exit %d" % r.returncode))
    ok = (r.returncode == 0) and ok

    boundary, seam, callers, sources = MANIFESTS

    ok = plant_text(
        rows, "boundary-gains-story-land", boundary,
        '"methods": [',
        '"methods": [{"wire_method": "story.land"}, ',
    ) and ok

    ok = plant_json_key(
        rows, "seam-gains-story-dot", seam,
        "story.land", {"id": "story.land"},
    ) and ok

    ok = plant_text(
        rows, "callers-gains-story-dot", callers,
        '"entries": [',
        '"entries": [{"file": "story.land.rb"}, ',
    ) and ok

    ok = plant_json_key(
        rows, "sources-gains-story-dot", sources,
        "story.schema", "contracts/storytime/linkml/story.land.yaml",
    ) and ok

    r = run()
    rows.append(("restored", r.returncode == 0, "exit %d" % r.returncode))
    ok = (r.returncode == 0) and ok

    print("plant_no_story_in_substrate_cpcp:")
    for name, passed, detail in rows:
        print("  %s  %s  %s" % ("ok" if passed else "FAIL", name, detail))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
