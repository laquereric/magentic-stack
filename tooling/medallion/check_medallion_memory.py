#!/usr/bin/env python3
"""The medallion memory contract holds, and the engine has not been forked in.

docs/architecture/plan_vv_medallion_memory.md names the rules; these are the
ones that are enforceable in this repo today, which is the set that does not
depend on the open M-home question:

  THREE BUILD TIERS   Bronze, Silver, Gold, and nothing else. Platinum is
                      refused BY NAME with the reason that makes it not a tier:
                      a weight matrix has no tombstone. Serving and Working get
                      the same treatment because both get proposed as ranks.

  NO ENGINE FORK      no Conformer, no Curator, no GraphProjection in this gem.
                      The plan lists forking mmg-medallion as a non-goal, and a
                      private Conformer "just to get going" is how it arrives.

  BLOCKER IS REAL     EngineBinding refuses medallion_home_undecided. A blocker
                      that is only a paragraph is one nobody trips over; someone
                      needs a Conformer, does not recall which document reserved
                      the decision, and writes one.

  REFUSALS FIRST      the ten named reasons exist before any happy path is
                      claimed, each with the condition it fires on.

  DISTILL IS BLOCKED  memory.distill names M5 and M9. Distilling before a
                      tombstone can cascade lets a forgotten fact come back out
                      of weights with nothing able to tell.

FAILS CLOSED: no gem, no specs, or a suite that runs zero examples is an error.
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
GEM = ROOT / "gems/vv-medallion_memory"
LIB = GEM / "lib/vv/medallion_memory"
PLAN = ROOT / "docs/architecture/plan_vv_medallion_memory.md"

BUILD_TIERS = ("bronze", "silver", "gold")

# Names that must be refused as Build tiers. Platinum is the one the plan argues
# at length; the other two are the ones that arrive wearing a different hat.
NOT_TIERS = ("platinum", "serving", "working")

# The refusals the plan lists as having to exist before the happy path.
REQUIRED_REASONS = (
    "bronze_mutated", "audit_rejected", "shacl_failed", "model_required",
    "contract_required", "principal_override_refused", "platinum_not_a_tier",
    "rag_write_undecided", "inferred_unbounded", "scope_violation",
)

# Engine classes that must NOT appear here. This is the fork, named.
ENGINE_CLASSES = ("Conformer", "Curator", "GraphProjection")

errors: list[str] = []


def rspec() -> tuple[bool, int, str]:
    proc = subprocess.run(
        ["bundle", "exec", "rspec", "--format", "progress"],
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
    specs = sorted((GEM / "spec").glob("*_spec.rb"))
    populated, _pop = emit_population(
        len(sources) + len(specs), skipped_reason="no vv-medallion_memory sources and no specs"
    )
    if not populated:
        return 1

    if not specs:
        errors.append("no specs; the contract is unasserted")

    # THREE BUILD TIERS.
    tier = LIB / "tier.rb"
    if not tier.is_file():
        errors.append("no tier.rb")
    else:
        body = tier.read_text(encoding="utf-8")
        slugs = re.findall(r'slug:\s*"(\w+)"', body)
        if tuple(slugs) != BUILD_TIERS:
            errors.append(
                "Build tiers are %s; the canonical three are %s. A fourth rank is exactly the "
                "maximalism audit! exists to reject" % (slugs, list(BUILD_TIERS))
            )
        for name in NOT_TIERS:
            if '"%s"' % name not in body:
                errors.append("tier.rb does not refuse %r as a Build tier by name" % name)
        if "tombstone" not in body:
            errors.append(
                "the platinum refusal does not say WHY (no tombstone); a refusal that cannot "
                "explain itself reads as an oversight and gets removed"
            )

    # NO ENGINE FORK.
    for path in sources:
        body = path.read_text(encoding="utf-8")
        for cls in ENGINE_CLASSES:
            if re.search(r"class\s+%s\b" % cls, body):
                errors.append(
                    "%s defines %s; forking mmg-medallion into this gem is a named non-goal"
                    % (path.relative_to(ROOT), cls)
                )

    # BLOCKER IS REAL.
    binding = LIB / "engine_binding.rb"
    if not binding.is_file():
        errors.append("no engine_binding.rb; the M-home blocker is not executable")
    else:
        body = binding.read_text(encoding="utf-8")
        if "MEDALLION_HOME_UNDECIDED" not in body:
            errors.append("engine_binding does not refuse medallion_home_undecided")
        pending = re.findall(r'"(M\d+)"', body)
        if len(set(pending)) != 10:
            errors.append(
                "engine_binding names %d of the 10 pending engine changes; a refusal that cannot "
                "say what it waits for is not actionable" % len(set(pending))
            )

    # REFUSALS FIRST.
    refusal = LIB / "refusal.rb"
    if not refusal.is_file():
        errors.append("no refusal.rb")
    else:
        body = refusal.read_text(encoding="utf-8")
        for reason in REQUIRED_REASONS:
            if '"%s"' % reason not in body:
                errors.append("refusal vocabulary is missing %r" % reason)

    # DISTILL IS BLOCKED.
    flow = LIB / "flow.rb"
    if flow.is_file():
        body = flow.read_text(encoding="utf-8")
        if "memory.distill" not in body:
            errors.append("no memory.distill flow declared")
        elif not re.search(r"blocked_by:\s*%w\[M5[\w-]*\s+M9[\w-]*\]", body):
            errors.append(
                "memory.distill is not blocked by M5 and M9; distilling before a tombstone can "
                "cascade lets a forgotten fact come back out of weights"
            )

    # The plan and the gem agree about the tiers. Two homes for one fact is how
    # a fact drifts, and this is the pair most worth pinning together.
    if PLAN.is_file():
        plan = PLAN.read_text(encoding="utf-8")
        if "Do not add Platinum to `CANONICAL_ROWS`" not in plan:
            errors.append("the plan no longer refuses Platinum in CANONICAL_ROWS")

    passed, examples, out = rspec()
    if not passed:
        tail = "\n".join(out.strip().splitlines()[-12:])
        errors.append("vv-medallion_memory specs failed (%d examples):\n%s" % (examples, tail))

    if errors:
        for e in errors:
            print("  FAIL %s" % e, file=sys.stderr)
        print("medallion memory: FAIL (%d)" % len(errors), file=sys.stderr)
        return 1
    print("medallion memory: OK (%d sources, %d examples)" % (len(sources), examples))
    return 0


if __name__ == "__main__":
    sys.exit(main())
