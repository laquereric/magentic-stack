#!/usr/bin/env python3
"""Plants for check_doc_counts. Proves the gate fails when it should.

The first plant reproduces the incident: a document asserting a count the code
contradicts. The second is the subtler one -- a doc reworded so the pattern no
longer matches, which makes the gate stop checking WITHOUT failing, and is how
a checker becomes decoration.

Restores every file it touches.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/governance/check_doc_counts.py"
CANONICAL = ROOT / "docs/architecture/CANONICAL.md"
README = ROOT / "README.md"
CATALOG = ROOT / "gems/rails-osi-level-8/lib/rails_osi_level_8/ui/catalog.rb"


def run():
    env = os.environ.copy()
    env.pop("CHECK_ROOT", None)
    return subprocess.run([sys.executable, str(CHECKER)], cwd=str(ROOT), env=env,
                          capture_output=True, text=True, timeout=300)


def plant(rows, name, path, mutate, marker=None):
    orig = path.read_text(encoding="utf-8")
    try:
        planted = mutate(orig)
        if planted == orig:
            rows.append((name, False, "could not plant -- the text it targets is gone"))
            return False
        path.write_text(planted, encoding="utf-8")
        r = run()
        caught = r.returncode != 0
        if marker:
            caught = caught and marker in (r.stdout + r.stderr)
        rows.append((name, caught, "exit %d" % r.returncode))
        return caught
    finally:
        path.write_text(orig, encoding="utf-8")


def main() -> int:
    rows: list[tuple[str, bool, str]] = []
    ok = True

    r = run()
    rows.append(("clean", r.returncode == 0, "exit %d" % r.returncode))
    ok = (r.returncode == 0) and ok

    # THE INCIDENT. CANONICAL.md claims seven where the catalog ships twelve.
    ok = plant(rows, "doc-says-seven-code-says-twelve", CANONICAL,
               lambda t: t.replace("Live `Ui::Catalog` ships all twelve",
                                   "Live `Ui::Catalog` ships seven", 1),
               "the tree says") and ok

    # The mirror: the CODE moves and the doc does not. Same disagreement,
    # opposite cause, and the gate must not care which side drifted.
    ok = plant(rows, "code-loses-a-kind", CATALOG,
               lambda t: t.replace('"kind" => "task.preview"', '"kind_removed" => "task.preview"', 1),
               "the tree says") and ok

    # A stale container count, which is what four of the five claims guard.
    ok = plant(rows, "stale-container-count", README,
               lambda t: t.replace("the fourteen-container MIND centered Pod",
                                   "the twelve-container MIND centered Pod", 1),
               "the tree says") and ok

    # THE SUBTLE ONE. Reword so the pattern misses. The claim is still in the
    # document and still wrong-able, but the gate would now pass in silence --
    # a checker that stopped checking and did not say so.
    ok = plant(rows, "reworded-so-the-pattern-misses", CANONICAL,
               lambda t: t.replace("Live `Ui::Catalog` ships all twelve",
                                   "The live catalog currently offers twelve", 1),
               "stopped checking") and ok

    r = run()
    rows.append(("restored", r.returncode == 0, "exit %d" % r.returncode))
    ok = (r.returncode == 0) and ok

    for name, passed, detail in rows:
        print("  %s %s -- %s" % ("ok" if passed else "FAIL", name, detail))
    print("population: %d examined, 0 skipped" % len(rows))
    print("plant doc-counts: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
