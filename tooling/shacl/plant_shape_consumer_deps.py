#!/usr/bin/env python3
"""Prove check_shape_consumer_deps.py fails on an undeclared consumer and
on empty CHECK_ROOT. Does not leave files behind.
"""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/shacl/check_shape_consumer_deps.py"


def run(env, cwd=None):
    return subprocess.run(
        [sys.executable, str(CHECKER)],
        cwd=str(cwd or ROOT),
        env=env,
        capture_output=True,
        text=True,
    )


def main():
    rows = []
    ok = True
    env = os.environ.copy()
    env.pop("CHECK_ROOT", None)

    r = run(env)
    rows.append(("clean", r.returncode == 0, "exit %d\n%s" % (r.returncode, r.stdout[-300:])))
    ok = ok and r.returncode == 0

    env_empty = env.copy()
    env_empty["CHECK_ROOT"] = ""
    r = run(env_empty)
    rows.append(("empty-CHECK_ROOT-fails", r.returncode != 0, "exit %d %s" % (r.returncode, r.stderr.strip())))
    ok = ok and r.returncode != 0

    with tempfile.TemporaryDirectory(prefix="gap90-") as tmp:
        tmp = Path(tmp)
        gem = tmp / "gems" / "fake-consumer"
        (gem / "lib").mkdir(parents=True)
        (gem / "lib" / "fake.rb").write_text('L8 = "shapes-level-8"\n')
        (gem / "fake-consumer.gemspec").write_text(
            'Gem::Specification.new do |s|\n'
            '  s.name = "fake-consumer"\n'
            '  s.version = "0.0.0"\n'
            '  s.add_dependency "rails", ">= 8.0"\n'
            "end\n"
        )
        env_plant = env.copy()
        env_plant["CHECK_ROOT"] = str(tmp)
        r = run(env_plant)
        rows.append(
            ("undeclared-consumer-fails", r.returncode != 0,
             "exit %d\n%s%s" % (r.returncode, r.stdout, r.stderr))
        )
        ok = ok and r.returncode != 0

    print("PLANT TABLE")
    for name, passed, detail in rows:
        print("  %s  %s: %s" % ("OK " if passed else "FAIL", name, detail.strip()[:240]))
    print("plant shape-consumer-deps: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
