#!/usr/bin/env python3
"""Plants for check_no_storytime_gem. Proves the gate fails when it should.

The load-bearing plant is a homepage-clean magentic-stack gemspec under
gems/vv-storytime/ — the thing check_closed.py would pass.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/boundary/check_no_storytime_gem.py"
PLANTED_DIR = ROOT / "gems/vv-storytime"
PERCH_SPEC = ROOT / "gems/vv-perch/vv-perch.gemspec"
APP_RB = ROOT / "gems/shapes-application/lib/shapes-application.rb"


def run():
    env = os.environ.copy()
    env.pop("CHECK_ROOT", None)
    return subprocess.run(
        [sys.executable, str(CHECKER)], cwd=str(ROOT), env=env,
        capture_output=True, text=True, timeout=120,
    )


def plant_file(rows, name, path, mutate):
    orig = path.read_text(encoding="utf-8")
    try:
        planted = mutate(orig)
        if planted == orig:
            rows.append((name, False, "could not plant -- the text it targets is gone"))
            return False
        path.write_text(planted, encoding="utf-8")
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

    if PLANTED_DIR.exists():
        rows.append(("homepage-clean-gemspec", False, "gems/vv-storytime/ already exists"))
        ok = False
    else:
        try:
            PLANTED_DIR.mkdir(parents=True)
            (PLANTED_DIR / "vv-storytime.gemspec").write_text(
                'Gem::Specification.new do |s|\n'
                '  s.name        = "vv-storytime"\n'
                '  s.version     = "0.0.0"\n'
                '  s.homepage    = "https://github.com/laquereric/magentic-stack"\n'
                '  s.metadata["source_code_uri"] = "https://github.com/laquereric/magentic-stack"\n'
                "end\n",
                encoding="utf-8",
            )
            r = run()
            rows.append(("homepage-clean-gemspec", r.returncode != 0, "exit %d" % r.returncode))
            ok = (r.returncode != 0) and ok
        finally:
            shutil.rmtree(PLANTED_DIR, ignore_errors=True)

    ok = plant_file(
        rows, "gemspec-named-storytime", PERCH_SPEC,
        lambda t: t.replace('s.name        = "vv-perch"', 's.name        = "storytime"'),
    ) and ok

    ok = plant_file(
        rows, "slot-dropped-from-applications", APP_RB,
        lambda t: t.replace(" sharedai-space storytime].freeze", " sharedai-space].freeze"),
    ) and ok

    r = run()
    rows.append(("restored", r.returncode == 0, "exit %d" % r.returncode))
    ok = (r.returncode == 0) and ok

    print("plant_no_storytime_gem:")
    for name, passed, detail in rows:
        print("  %s  %s  %s" % ("ok" if passed else "FAIL", name, detail))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
