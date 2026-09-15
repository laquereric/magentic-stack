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
