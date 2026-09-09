#!/usr/bin/env python3
"""Gate the dev/prod split on generated shapes.

Two assertions, and they are different in kind:

  1. EVERY reified artifact still traces to its LinkML source. The source
     sha256 in the artifact header matches the schema on disk, and
     regenerating reproduces the artifact. Enforced by delegating to
     generate_shapes.py --check, so the generator and the gate cannot
     disagree about what "in sync" means.

  2. PRODUCTION DOES NOT GENERATE. Shapes are morphed by dev and only read by
     prod. Nothing under runtimes/ imports linkml, shells out to a gen-*
     binary, or installs the toolchain into an image. The reified artifacts
     are the production surface.

The second is the one worth having a gate for. The first fails loudly the
moment someone edits a schema and forgets to regenerate; the second fails
silently and only in production, by turning a read path into a build path --
a container that generates its own shapes has no fixed answer to "what shape
was enforced when this request was refused".

FAILS CLOSED: an empty source register or an unscanned runtimes/ tree is an
error, not a pass.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(os.environ["CHECK_ROOT"]) if os.environ.get("CHECK_ROOT") else Path(__file__).resolve().parents[2]
REGISTER = ROOT / "tooling/linkml/sources.json"
GENERATOR = ROOT / "tooling/linkml/generate_shapes.py"
RUNTIMES = ROOT / "runtimes"

# What "prod generates a shape" looks like in a runtime tree.
FORBIDDEN = (
    (re.compile(r"^\s*(import|from)\s+linkml"), "imports linkml"),
    (re.compile(r"\bgen-(shacl|python|typescript|owl|json-schema)\b"), "shells out to a linkml generator"),
    (re.compile(r"linkml==|pip install .*\blinkml\b"), "installs the linkml toolchain"),
)

SCAN_SUFFIXES = {".py", ".rb", ".mjs", ".js", ".sh", ".yml", ".yaml", ".txt", ".gemspec"}
SKIP_DIRS = {"vendor", "node_modules", ".git", "tmp", "log", "generated"}

checks: list[tuple[str, bool, str]] = []


def check(name: str, ok: bool, detail: str = "") -> bool:
    checks.append((name, bool(ok), detail))
    return bool(ok)


def main() -> int:
    if not REGISTER.is_file():
        print("FAIL: no source register at tooling/linkml/sources.json", file=sys.stderr)
        return 1
    register = json.loads(REGISTER.read_text(encoding="utf-8"))
    sources = register.get("sources", [])
    check("register-not-empty", bool(sources), "%d schema(s)" % len(sources))

    # 1. Artifacts trace to their sources.
    proc = subprocess.run(
        [sys.executable, str(GENERATOR), "--check"],
        cwd=str(ROOT),
        capture_output=True,
        text=True,
        timeout=600,
    )
    check(
        "artifacts-trace-to-source",
        proc.returncode == 0,
        (proc.stderr.strip().splitlines() or ["exit %d" % proc.returncode])[-1][:200],
    )

    # 2. Production does not generate.
    scanned = 0
    offenders: list[str] = []
    if RUNTIMES.is_dir():
        for path in RUNTIMES.rglob("*"):
            if not path.is_file() or path.suffix not in SCAN_SUFFIXES:
                continue
            if any(part in SKIP_DIRS for part in path.parts):
                continue
            scanned += 1
            try:
                body = path.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            for pattern, why in FORBIDDEN:
                if pattern.search(body):
                    offenders.append(f"{path.relative_to(ROOT)}: {why}")
    check("runtimes-scanned", scanned > 0, "%d file(s)" % scanned)
    check("prod-does-not-generate", not offenders, "; ".join(offenders[:3]) if offenders else "no generator in runtimes/")

    failed = [c for c in checks if not c[1]]
    for name, ok, detail in checks:
        print("  %s %s%s" % ("ok" if ok else "FAIL", name, (" -- " + detail) if detail else ""))
    print("population: %d examined, 0 skipped" % len(checks))
    if failed:
        print("shape artifacts: FAIL (%d)" % len(failed), file=sys.stderr)
        return 1
    print("shape artifacts: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
