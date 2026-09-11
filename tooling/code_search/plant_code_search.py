#!/usr/bin/env python3
"""Plants for check_code_search. Proves the gate fails when it should.

plan_vv-code-search names its gates and each one that the built scope covers
gets a plant that triggers exactly it. A checker that has never been planted is
not a gate; it is a function nobody has watched refuse.

The two most important plants here are the ones that put back the failure the
gem exists to prevent:

  absence-collapsed   report "never read this file" as an empty hit list, which
                      is the index miss that reads like evidence
  scanner-admitted    admit a dimension that cannot answer by line, which is how
                      a sub-millisecond hover quietly becomes a four-second one

Restores every file it touches.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/code_search/check_code_search.py"
LIB = ROOT / "gems/vv-code-search/lib/vv/code_search"
LOOKUP = LIB / "lookup.rb"
INDEX = LIB / "index.rb"
ENTRY = LIB.parent / "code_search.rb"
PINS = LIB / "dimensions/pins.rb"
GEMSPEC = ROOT / "gems/vv-code-search/vv-code-search.gemspec"


def run():
    env = os.environ.copy()
    env.pop("CHECK_ROOT", None)
    return subprocess.run([sys.executable, str(CHECKER)], cwd=str(ROOT), env=env,
                          capture_output=True, text=True, timeout=900)


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

    # THE CENTRAL ONE. A dimension that never read a file reports an empty hit
    # list instead of saying so, and the caller cannot tell the miss from the
    # evidence. This is the exact failure the plan says makes an index worse
    # than the grep it replaces.
    ok = plant(rows, "absence-collapsed", LOOKUP,
               lambda t: t.replace(
                   '          return {\n            indexed: false,\n'
                   '            because: "#{name} did not read #{path}; silence here is not evidence"\n'
                   '          }',
                   '          return { indexed: true, hits: [] }')) and ok

    # The whole-rev refusal downgraded to a success with nothing in it.
    ok = plant(rows, "not-indexed-becomes-empty", LOOKUP,
               lambda t: t.replace(
                   'return Envelope.refuse("not_indexed", "no index was supplied for this (repo, fork, rev, schema)") if index.nil?',
                   'return Envelope.ok(line: {}, dimensions: {}) if index.nil?')) and ok

    # A scan-shaped dimension admitted to the hot union.
    ok = plant(rows, "scanner-admitted", PINS,
               lambda t: t.replace("def point_query? = true", "def point_query? = false")) and ok

    # Identity loses the schema, so two schemas over one rev land on one digest
    # and silently merge.
    ok = plant(rows, "schema-drops-out-of-identity", INDEX,
               lambda t: t.replace(
                   "Digest::SHA256.hexdigest([repo, fork, rev, schema_id].join(\"\\n\"))",
                   "Digest::SHA256.hexdigest([repo, fork, rev].join(\"\\n\"))")) and ok

    # The collision refusal removed: a digest that already holds another
    # identity gets written over.
    ok = plant(rows, "collision-unchecked", INDEX,
               lambda t: t.replace('"schema_collision",', '"not_indexed",')) and ok

    # A pin manifest's rollback target promoted to a declaration, collapsing the
    # distinction the reverse question depends on.
    ok = plant(rows, "references-become-declarations", PINS,
               lambda t: t.replace(
                   'out[no] << entry("references", "git", name, m[1], "pin manifest rollback target")',
                   'out[no] << entry("declares", "git", name, m[1], "pin manifest rollback target")')) and ok

    # The gem becomes pushable, which is a second home waiting to happen.
    ok = plant(rows, "gem-becomes-pushable", GEMSPEC,
               lambda t: t.replace('"allowed_push_host" => "none"',
                                   '"allowed_push_host" => "https://rubygems.org"')) and ok

    # A schema that registers nothing: an index over no dimensions passes every
    # timing assertion while measuring nothing.
    ok = plant(rows, "empty-schema", ENTRY,
               lambda t: t.replace("dimensions: [Dimensions::Pins, Dimensions::Lexical],",
                                   "dimensions: [],")
                          .replace("dimensions: [Dimensions::Pins],", "dimensions: [],")) and ok

    r = run()
    rows.append(("restored", r.returncode == 0, "exit %d" % r.returncode))
    ok = (r.returncode == 0) and ok

    for name, passed, detail in rows:
        print("  %s %s -- %s" % ("ok" if passed else "FAIL", name, detail))
    print("population: %d examined, 0 skipped" % len(rows))
    print("plant code-search: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
