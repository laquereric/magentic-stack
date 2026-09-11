#!/usr/bin/env python3
"""vv-code-search keeps the distinctions its plan is built on.

docs/architecture/plan_vv-code-search.md names the gates; these are them. The
gem's own suite proves the behaviour, and this runs the fast half of it so the
sweep fails on a regression rather than waiting for bin/spec-all. What is added
here is the structural half a spec cannot assert about itself:

  ABSENCE IS A SIGNAL   three outcomes stay distinct -- the rev was never
                        indexed, the dimension never read this file, and the
                        dimension looked and found nothing. Only the third is
                        evidence, and collapsing them reproduces the failure the
                        lexical dimension exists to avoid.

  HOT UNION IS CLOSED   every dimension a registered schema names answers
                        point_query?. The bound is enforced at registration
                        because measuring per request is already too late.

  IDENTITY, NOT MERGE   two schemas over one (repo, fork, rev) get two digests.
                        The plan forbids a silent merge; addressing prevents it
                        rather than a check someone has to remember to run.

  CLOSED GEM            no allowed_push_host but "none". ADR 0038: a gem here
                        has no other home, and a gemspec that names one is how
                        divergence starts.

FAILS CLOSED: no gem, no specs, or a suite that runs zero examples is an error.
A green run over an empty population is worse than no check.
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population  # noqa: E402

ROOT = Path(os.environ["CHECK_ROOT"]) if os.environ.get("CHECK_ROOT") else Path(__file__).resolve().parents[2]
GEM = ROOT / "gems/vv-code-search"
LIB = GEM / "lib/vv/code_search"

# The fast specs. bound_spec.rb indexes the whole monorepo and belongs in
# bin/spec-all, not in a gate that runs on every sweep -- a five-second index is
# not a per-sweep cost worth paying for a property CI already proves.
FAST_SPECS = ("spec/absence_spec.rb", "spec/index_identity_spec.rb", "spec/pins_spec.rb")

errors: list[str] = []


def rspec() -> tuple[bool, int, str]:
    """(passed, examples, output). Zero examples is not a pass."""
    proc = subprocess.run(
        ["bundle", "exec", "rspec", *FAST_SPECS, "--format", "progress"],
        cwd=str(GEM), capture_output=True, text=True, timeout=600,
    )
    out = proc.stdout + proc.stderr
    m = re.search(r"(\d+) examples?, (\d+) failures?", out)
    if not m:
        return False, 0, out
    examples, failures = int(m.group(1)), int(m.group(2))
    return proc.returncode == 0 and failures == 0 and examples > 0, examples, out


def main() -> int:
    if not GEM.is_dir():
        print("FAIL: no gem at %s" % GEM, file=sys.stderr)
        emit_population(0)
        return 1

    sources = sorted(LIB.rglob("*.rb"))
    specs = [GEM / s for s in FAST_SPECS]
    missing = [s for s in specs if not s.is_file()]
    populated, _pop = emit_population(
        len(sources) + len(specs) - len(missing),
        skipped_reason="no vv-code-search sources and no specs",
    )
    if not populated:
        return 1

    for spec in missing:
        errors.append("missing spec %s; the behaviour it covers is ungated" % spec.relative_to(ROOT))

    # CLOSED GEM. ADR 0038.
    gemspec = GEM / "vv-code-search.gemspec"
    if not gemspec.is_file():
        errors.append("no gemspec")
    else:
        text = gemspec.read_text(encoding="utf-8")
        if '"allowed_push_host" => "none"' not in text:
            errors.append(
                "gemspec does not set allowed_push_host to none; this gem is closed (ADR 0038) "
                "and a pushable private gem is a second home waiting to happen"
            )

    # HOT UNION IS CLOSED. Read the registrations rather than trusting the
    # comment beside them: a dimension is admitted by code, so the check has to
    # read code.
    entry = LIB.parent / "code_search.rb"
    if not entry.is_file():
        errors.append("no lib/vv/code_search.rb")
    else:
        registered = re.findall(r"Dimensions::(\w+)", entry.read_text(encoding="utf-8"))
        if not registered:
            errors.append("no schema registers any dimension -- an index over nothing is not a gate")
        for name in sorted(set(registered)):
            source = LIB / "dimensions" / ("%s.rb" % re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower())
            if not source.is_file():
                errors.append("schema names Dimensions::%s with no source at %s" % (name, source.name))
                continue
            body = source.read_text(encoding="utf-8")
            if "def point_query? = true" not in body:
                errors.append(
                    "Dimensions::%s is registered in a schema but does not declare point_query? = true; "
                    "a dimension that cannot answer by line stays batch" % name
                )

    # ABSENCE IS A SIGNAL. The three outcomes have to be spelled in the code,
    # not only in the doc.
    lookup = LIB / "lookup.rb"
    if not lookup.is_file():
        errors.append("no lookup.rb")
    else:
        body = lookup.read_text(encoding="utf-8")
        for needle, why in (
            ("indexed: false", "the 'never read this file' outcome"),
            ("indexed: true", "the 'looked and found nothing' outcome"),
            ("not_indexed", "the 'nothing was built' outcome"),
        ):
            if needle not in body:
                errors.append("lookup.rb has no %s (%s)" % (needle, why))

    # IDENTITY, NOT MERGE.
    index = LIB / "index.rb"
    if index.is_file():
        body = index.read_text(encoding="utf-8")
        if "schema_id" not in body or "digest_for" not in body:
            errors.append("index identity does not include schema_id; two schemas could merge")
        if "schema_collision" not in body:
            errors.append("index build does not refuse a digest already holding another identity")

    # The behaviour itself.
    passed, examples, out = rspec()
    if not passed:
        tail = "\n".join(out.strip().splitlines()[-12:])
        errors.append("vv-code-search fast specs failed (%d examples):\n%s" % (examples, tail))
    elif examples == 0:
        errors.append("vv-code-search specs ran zero examples")

    if errors:
        for e in errors:
            print("  FAIL %s" % e, file=sys.stderr)
        print("code search: FAIL (%d)" % len(errors), file=sys.stderr)
        return 1
    print("code search: OK (%d ruby sources, %d fast examples)" % (len(sources), examples))
    return 0


if __name__ == "__main__":
    sys.exit(main())
