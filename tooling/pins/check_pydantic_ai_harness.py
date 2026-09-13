#!/usr/bin/env python3
"""Fail if ADR 0001 drops the pydantic-ai-harness citation, or we vendor it.

docs/pydantic-upgrades.md rec 5. Cite it; do not vendor it. Empty
CHECK_ROOT fails. A second agent runtime beside NOOA is the failure
this gate exists to prevent.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

ADR = Path("docs/adr/0001-ownership-boundary.md")
REQ = Path("runtimes/mind-pod/mind/requirements.txt")
GITMODULES = Path(".gitmodules")
SKIP = {".git", "node_modules", ".venv", "__pycache__", "dist", "tmp"}
IMPORT_NEEDLES = ("import pydantic_ai", "from pydantic_ai", "import pydantic_ai_harness", "from pydantic_ai_harness")


def fail_empty_check_root():
    if "CHECK_ROOT" in os.environ and not str(os.environ.get("CHECK_ROOT", "")).strip():
        print("FAIL: empty CHECK_ROOT", file=sys.stderr)
        return True
    return False


def root_from_env():
    raw = os.environ.get("CHECK_ROOT")
    if raw is None:
        return Path(__file__).resolve().parents[2]
    return Path(raw)


def main() -> int:
    if fail_empty_check_root():
        return 1
    root = root_from_env()
    checks = []

    def check(name, ok, detail=""):
        checks.append((name, bool(ok), str(detail)))
        return bool(ok)

    adr = (root / ADR).read_text(encoding="utf-8") if (root / ADR).is_file() else ""
    req = (root / REQ).read_text(encoding="utf-8") if (root / REQ).is_file() else ""
    gm = (root / GITMODULES).read_text(encoding="utf-8") if (root / GITMODULES).is_file() else ""
    ok = True
    ok = check("adr-present", bool(adr), str(ADR)) and ok
    ok = check("cites-harness", "pydantic-ai-harness" in adr, "ADR 0001") and ok
    ok = check("do-not-vendor", "do not vendor it" in adr.lower(), "do not vendor it") and ok
    ok = check("effect-surface", "Effect surface" in adr, "bounded Effect surface") and ok
    ok = check("cites-url", "github.com/pydantic/pydantic-ai-harness" in adr, "source URL") and ok
    ok = check("no-upstreams-harness", not (root / "upstreams" / "pydantic-ai-harness").exists(), "no upstreams home") and ok
    ok = check("no-upstreams-pydantic-ai", not (root / "upstreams" / "pydantic-ai").exists(), "no pydantic-ai home") and ok
    ok = check("no-gitmodules", "pydantic-ai" not in gm, ".gitmodules") and ok
    req_code = "\n".join(ln.split("#", 1)[0] for ln in req.splitlines())
    ok = check("no-mind-dep", "pydantic-ai" not in req_code, "requirements.txt") and ok

    hits = []
    runtimes = root / "runtimes"
    examined_rt = 0
    if runtimes.is_dir():
        for path in runtimes.rglob("*"):
            if any(p in SKIP for p in path.parts):
                continue
            if path.suffix not in {".py", ".rb", ".mjs", ".js"}:
                continue
            examined_rt += 1
            try:
                text = path.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            for i, line in enumerate(text.splitlines(), 1):
                code = line.split("#", 1)[0]
                if any(n in code for n in IMPORT_NEEDLES):
                    hits.append("%s:%d" % (path.relative_to(root).as_posix(), i))
    ok = check("no-runtime-import", not hits, "clean" if not hits else ", ".join(hits[:5])) and ok

    populated, _pop = emit_population(len(checks) + examined_rt)
    if not populated:
        return 1
    print("check | ok | detail")
    print("------|----|--------")
    for name, passed, detail in checks:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    if not ok:
        print("pydantic-ai-harness: FAIL", file=sys.stderr)
        return 1
    print("pydantic-ai-harness: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
