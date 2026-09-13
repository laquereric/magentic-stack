#!/usr/bin/env python3
"""Fail if the monty pin moves without a re-review, or the gitlink drifts.

ADR 0070. accepted_pin in the ADR, live pin in pin.json, gitlink must
equal pinned_revision. Empty CHECK_ROOT fails. Unpopulated submodule is
not drift (worktrees do not init submodules by default).
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

ADR = Path("docs/adr/0070-monty-is-the-codeact-isolation-seam.md")
PIN = Path("upstreams/manifests/monty.pin.json")
SHA_RE = re.compile(r"^[0-9a-f]{40}$")
ACCEPTED_RE = re.compile(r'^accepted_pin:\s*"([0-9a-f]{40})"', re.M)


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


def git(args, cwd):
    try:
        return subprocess.run(
            ["git", *args], cwd=str(cwd), capture_output=True, text=True, timeout=30
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None


def gitlink_sha(root: Path, sub: str):
    r = git(["ls-files", "-s", "--", sub], root)
    if r and r.returncode == 0 and r.stdout.strip():
        for tok in r.stdout.split():
            if SHA_RE.match(tok):
                return tok, None
    r = git(["ls-tree", "HEAD", sub], root)
    if r is None or r.returncode != 0:
        return None, (r.stderr.strip() if r else "git missing")
    for tok in r.stdout.split():
        if SHA_RE.match(tok):
            return tok, None
    return None, "no 40-hex gitlink for %s" % sub


def main() -> int:
    if fail_empty_check_root():
        return 1
    root = root_from_env()
    errors = []
    examined = 0

    examined += 1
    adr = (root / ADR).read_text(encoding="utf-8") if (root / ADR).is_file() else ""
    if not adr:
        errors.append("missing %s" % ADR.as_posix())
    am = ACCEPTED_RE.search(adr)
    accepted = am.group(1) if am else ""
    if not accepted:
        errors.append("ADR 0070 missing accepted_pin 40-hex")
    if "CPython is not a fallback" not in adr and "do not call nxt" not in adr.lower():
        if "Wrap NOOA" not in adr:
            errors.append("ADR 0070 no longer says wrap NOOA CodeAct")

    examined += 1
    pin_path = root / PIN
    pin = json.loads(pin_path.read_text(encoding="utf-8")) if pin_path.is_file() else {}
    live = str(pin.get("pinned_revision") or "")
    if not SHA_RE.match(live):
        errors.append("pin.json pinned_revision is not 40-hex")
    sub = str(pin.get("submodule_path") or "").strip()
    if not sub:
        errors.append("pin.json submodule_path missing")
    if pin.get("fork") is not False:
        errors.append("pin.json fork is not false")
    gm = (root / ".gitmodules").read_text(encoding="utf-8") if (root / ".gitmodules").is_file() else ""
    if sub and sub not in gm:
        errors.append("submodule_path not in .gitmodules")
    if "github.com/pydantic/monty" not in gm:
        errors.append(".gitmodules missing pydantic/monty url")

    if accepted and live and accepted != live:
        reviews = pin.get("reviews") or []
        if not any(str(r.get("sha") or "") == live and r.get("looked_at") and r.get("because") for r in reviews):
            errors.append("live pin moved from accepted_pin without a filled reviews[] row")

    examined += 1
    if sub:
        gl, why = gitlink_sha(root, sub)
        if gl is None:
            # Before the first commit of this slice, HEAD has no gitlink.
            # Working tree still must declare the path.
            print("  note gitlink %s" % why)
        elif gl != live:
            errors.append("gitlink %s != pinned_revision %s" % (gl, live))
        else:
            print("  ok gitlink %s" % gl)

    adapter = root / "gems/adapters/monty/run.py"
    examined += 1
    if not adapter.is_file():
        errors.append("missing gems/adapters/monty/run.py")
    else:
        src = adapter.read_text(encoding="utf-8")
        if "CPython is not a fallback" not in src:
            errors.append("adapter run.py dropped the no-CPython claim")

    populated, _pop = emit_population(examined)
    if not populated:
        return 1
    if errors:
        for e in errors:
            print("FAIL:", e, file=sys.stderr)
        return 1
    print("monty-pin: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
