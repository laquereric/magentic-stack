#!/usr/bin/env python3
"""vv-perch schema refusals. Each rule is planted.

The plan's four refusals and the count that must stay unavailable: a
boolean on perch_methods named released/delivered/done/shipped/complete
would let someone SUM methods as throughput.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population  # noqa: E402

ROOT = Path(os.environ["CHECK_ROOT"]) if os.environ.get("CHECK_ROOT") else Path(__file__).resolve().parents[2]
GEM = ROOT / "gems/vv-perch"
MIG = GEM / "db/migrate"
LIB = GEM / "lib"

FORBIDDEN_SECRET = re.compile(r"\b(jws|signature|token|secret|credential)\b", re.I)
FORBIDDEN_RANK = re.compile(r"\b(priority|position|rank)\b", re.I)
RANK_TOGETHER = re.compile(r"\brank_together\b")
METHOD_BOOL = re.compile(
    r"t\.boolean\s+:(released|delivered|done|shipped|complete)\b"
)
EXECUTOR = re.compile(r"t\.\w+\s+:(executor|credential)\b")
RELEASED_AT_WRITE = re.compile(r"released_at\s*=|update!\(\s*released_at:|update_column\(:released_at")
FLOOR_CONST = re.compile(r"T[1-5]\s*=")

errors: list[str] = []


def code_without_comments(text: str) -> str:
    out = []
    for line in text.splitlines():
        if line.lstrip().startswith("#"):
            continue
        out.append(re.sub(r"#.*$", "", line))
    return "\n".join(out)


def main() -> int:
    if not GEM.is_dir():
        print("FAIL: no gem at %s" % GEM, file=sys.stderr)
        emit_population(0)
        return 1

    sources = sorted(p for p in (list(LIB.rglob("*.rb")) + list(MIG.glob("*.rb"))) if p.is_file())
    populated, _ = emit_population(len(sources), skipped_reason="no vv-perch sources")
    if not populated:
        return 1

    # Fifteen tables.
    mig_text = "\n".join(p.read_text(encoding="utf-8") for p in sorted(MIG.glob("*.rb")))
    tables = re.findall(r"create_table\s+:(perch_\w+)", mig_text)
    if len(tables) != 15:
        errors.append("expected 15 perch_ tables, found %d: %s" % (len(tables), tables))

    for path in sources:
        rel = path.relative_to(ROOT).as_posix()
        raw = path.read_text(encoding="utf-8")
        code = code_without_comments(raw)

        for m in FORBIDDEN_SECRET.finditer(code):
            errors.append("%s names %s (R3: no signatures/credentials)" % (rel, m.group(1)))

        for m in FORBIDDEN_RANK.finditer(code):
            start = max(0, m.start() - 20)
            window = code[start:m.end() + 20]
            if RANK_TOGETHER.search(window) and m.group(1).lower() == "rank":
                continue
            errors.append("%s names %s (R4: no ranking; rank_together is the allowlist)" % (rel, m.group(1)))

        if path.name.endswith(".rb") and "create_table :perch_methods" in raw:
            if METHOD_BOOL.search(code):
                errors.append("%s has a delivery boolean on perch_methods; throughput is released slices" % rel)

        if "create_table :perch_effect_bindings" in raw and EXECUTOR.search(code):
            errors.append("%s has executor/credential on perch_effect_bindings (R1)" % rel)

        if path.suffix == ".rb" and "lib/vv/perch" in rel:
            if RELEASED_AT_WRITE.search(code) and "release_group.rb" not in rel:
                errors.append("%s writes released_at; only ReleaseGroup#release! may" % rel)

    # STAGE 2. Only an OUTWARD reading is evidence the receiver's aim was met
    # (perchv2 12.1). The first cut matched every reading carrying a matured_at
    # and had no class filter above it, so a matured INWARD verdict -- a test
    # pass -- finished the slice. That inverts the rule with a missing WHERE,
    # and it is invisible in review because the three state names were already
    # correct.
    signal = GEM / "lib/vv/perch/outward_signal.rb"
    if not signal.is_file():
        errors.append("no lib/vv/perch/outward_signal.rb; the outward signal is stage 2")
    else:
        body = code_without_comments(signal.read_text(encoding="utf-8"))
        if 'signal_class: "outward"' not in body:
            errors.append(
                "outward_signal.rb does not filter readings to signal_class outward; an inward "
                "verdict would finish a slice, which is 12.1 inverted"
            )
        # Asking whether delay_iso8601 is MENTIONED is not enough -- it appears
        # in the validation and the error text regardless. The window has to be
        # COMPUTED, so require the arithmetic that closes it.
        if not re.search(r"observed_at\s*\+", body):
            errors.append(
                "outward_signal.rb never adds the delay to observed_at, so no window is computed; "
                "pending would mean 'nobody stamped a column' instead of 'the window has not "
                "closed', and the window IS the measurement"
            )
        if "delay_seconds" not in body:
            errors.append("outward_signal.rb does not derive delay_seconds from delay_iso8601")
        for state in ("not_instrumented", "pending", "reporting"):
            if state not in body:
                errors.append("outward_signal.rb does not name the %r state" % state)

    # STAGE 3. F5 prices a change BEFORE it is accepted. The first cut had the
    # cascade and no pricing, and cost_shown_at_climb / climbed_at had no writer
    # at all -- columns only specs filled in. A record of "what I was shown"
    # that nothing writes is not evidence, and a cascade set is not a price.
    freeze = GEM / "lib/vv/perch/freeze.rb"
    if not freeze.is_file():
        errors.append("no lib/vv/perch/freeze.rb; the freeze ladder is stage 3")
    else:
        body = code_without_comments(freeze.read_text(encoding="utf-8"))
        if not re.search(r"def self\.price\s*\(", body):
            errors.append(
                "freeze.rb computes no price; F5 shows the reversal cost for everything above a "
                "change before the author accepts, and a cascade set is not a cost"
            )
        if "cost_shown_at_climb:" not in body:
            errors.append(
                "freeze.rb never writes cost_shown_at_climb; a record of what the climber was "
                "shown that nothing writes is a column, not evidence"
            )
        # 6.1 prices by WHO BEARS IT. A change at rung 3 is cheap for the author
        # and expensive for the ML team, which is the whole point of showing it.
        if "bearer" not in body:
            errors.append("freeze.rb prices without naming who bears the cost (perchv2 6.1)")
        # 6.3 shows gpu_hours: 180. This gem has no basis for that number.
        if re.search(r"gpu_hours\"?\s*(=>|:)\s*\d", body):
            errors.append(
                "freeze.rb reports an invented magnitude; counts and bearers are measurable here, "
                "hours are not, and a made-up number is acted on"
            )

    edge = GEM / "lib/vv/perch/freeze_edge.rb"
    if edge.is_file() and "cascade_from" not in code_without_comments(edge.read_text(encoding="utf-8")):
        errors.append(
            "freeze_edge.rb does not check reachability; a cycle does not hang (cascade_from has a "
            "seen guard) -- it prices wrongly and silently, which is worse"
        )

    # STAGE 4. P3: orphaning is a price payable only if the liability is written
    # down AND managed, and 11.2 lists the seven obligations that constitute
    # managing it. The first cut had the columns and one presence validation, so
    # an entry could be open while discharging none of them -- an unmanaged
    # liability wearing a ledger entry, which reads as handled.
    orphan = GEM / "lib/vv/perch/orphan.rb"
    if not orphan.is_file():
        errors.append("no lib/vv/perch/orphan.rb; the orphan ledger is stage 4")
    else:
        body = code_without_comments(orphan.read_text(encoding="utf-8"))
        if not re.search(r"def unmet_obligations\b", body):
            errors.append(
                "orphan.rb does not enumerate unmet obligations; 11.2 is seven obligations and "
                "'what does this still owe' has to be a list, not a judgement"
            )
        # 11.1: a boundary through the middle of one purpose is to QUESTION, not
        # to manage. Collapsing the two means answering it by scheduling harder.
        if "boundary_to_question" not in body:
            errors.append(
                "orphan.rb does not distinguish a boundary_to_question from a dependency to "
                "manage (11.1); the two call for opposite responses"
            )
        # 11.3 convergence is derived from p85 cycle times and must not be stored.
        if "start_offset_days:" not in body:
            errors.append("orphan.rb computes no convergence offset (11.3)")

    for path in MIG.glob("*.rb"):
        raw = path.read_text(encoding="utf-8")
        if re.search(r"t\.\w+\s+:start_offset_days\b", raw) or re.search(r"t\.\w+\s+:start_first\b", raw):
            errors.append(
                "%s stores the convergence offset; cycle times move, and a stored offset is a plan "
                "that quietly stopped describing the work" % path.relative_to(ROOT).as_posix()
            )

    # `done` is computed from released + instrumented + reporting. A column
    # would let it be written directly, and it would be written optimistically.
    for path in MIG.glob("*.rb"):
        raw = path.read_text(encoding="utf-8")
        if "create_table :perch_slices" in raw and re.search(r"t\.\w+\s+:(done|succeeding)\b", raw):
            errors.append(
                "%s stores done/succeeding on perch_slices; 12.1 computes both"
                % path.relative_to(ROOT).as_posix()
            )

    refusals = GEM / "lib/vv/perch/refusals.rb"
    if not refusals.is_file():
        errors.append("no lib/vv/perch/refusals.rb")
    else:
        text = refusals.read_text(encoding="utf-8")
        for n in range(1, 6):
            if not re.search(r"T%d\s*=" % n, text):
                errors.append("T%d has no named refusal constant" % n)

    doctrine = GEM / "lib/vv/perch/doctrine.rb"
    if not doctrine.is_file():
        errors.append("no doctrine.rb; O1–O4 would live only in chat")
    else:
        dtext = doctrine.read_text(encoding="utf-8")
        for const in ("BY_RECEIVER_IN_GOVERNANCE", "DRAFT_NAMESPACE", "NOOA_FORK_REFUSED",
                      "DEFAULT_PLACEMENT"):
            if const not in dtext:
                errors.append("Doctrine missing %s" % const)
        if 'DEFAULT_PLACEMENT = "canonical"' not in dtext:
            errors.append("O4 default placement is not canonical")
        if "NOOA_FORK_REFUSED = true" not in dtext:
            errors.append("O3 must refuse a NOOA fork by name")

    for path in sources:
        code = code_without_comments(path.read_text(encoding="utf-8"))
        if re.search(r"""require\s+["']nooa["']""", code):
            errors.append("%s requires nooa; O3 is pin, never fork" % path.relative_to(ROOT))

    seam = ROOT / "runtimes/mind-pod/app/lib/perch_seam.rb"
    init = ROOT / "runtimes/mind-pod/app/config/initializers/rails_cpcp.rb"
    routes = ROOT / "runtimes/mind-pod/app/config/routes.rb"
    if not seam.is_file():
        errors.append("no perch_seam.rb; T4 and release! would have no ActorBinding")
    else:
        stext = seam.read_text(encoding="utf-8")
        if "ActorBinding" not in stext:
            errors.append("perch_seam does not reuse ActorBinding (O1)")
        for method in ("perch.slice.restate", "perch.release", "perch.slice.status",
                       "perch.signal.report"):
            if method not in stext:
                errors.append("%s is not in the seam" % method)
    if init.is_file():
        itext = init.read_text(encoding="utf-8")
        for method in ("perch.slice.size", "perch.slice.status", "perch.slice.restate",
                       "perch.freeze.cascade", "perch.orphan.open", "perch.signal.report",
                       "perch.release"):
            if 'operation "%s"' % method not in itext:
                errors.append("%s is not registered on BACK" % method)
    if routes.is_file() and 'when "perch"' in routes.read_text(encoding="utf-8"):
        errors.append("routes.rb declares ROLE=perch; rows are domain state on BACK (ADR 0056)")

    if errors:
        print("FAIL: perch schema (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  %s" % e, file=sys.stderr)
        return 1
    print("perch schema: OK (%d sources, %d tables)" % (len(sources), len(tables)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
