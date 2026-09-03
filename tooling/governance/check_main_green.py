#!/usr/bin/env python3
"""Fail if main can be pushed without a green checker+plant sweep.

Row 114. core.hooksPath pre-push is the refuse; CI is the net.
Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

SWEEP = Path("bin/sweep")
HOOK = Path("tooling/githooks/pre-push")
INSTALL = Path("bin/install-hooks")
EXCL = Path("tooling/governance/sweep_exclusions.json")
WORKFLOW = Path(".github/workflows/main-green.yml")
DOC = Path("docs/architecture/ROW114.md")


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


def git_config(root: Path, key: str):
    try:
        r = subprocess.run(
            ["git", "config", "--get", key],
            cwd=str(root),
            capture_output=True,
            text=True,
            timeout=15,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None
    if r.returncode != 0:
        return ""
    return (r.stdout or "").strip()


def main():
    if fail_empty_check_root():
        return 1
    root = root_from_env()
    if not root.is_dir():
        print("FAIL: CHECK_ROOT is not a directory: %s" % root, file=sys.stderr)
        return 1
    try:
        nonempty = any(root.iterdir())
    except OSError as e:
        print("FAIL: CHECK_ROOT unreadable: %s" % e, file=sys.stderr)
        return 1
    if not nonempty:
        print("FAIL: empty CHECK_ROOT tree", file=sys.stderr)
        return 1

    errors = []
    examined = 0

    for rel in (SWEEP, HOOK, INSTALL, EXCL, WORKFLOW, DOC):
        examined += 1
        p = root / rel
        if not p.is_file():
            errors.append("missing %s" % rel.as_posix())
        else:
            print("  ok %s" % rel.as_posix())

    sweep_path = root / SWEEP
    sweep = sweep_path.read_text(encoding="utf-8", errors="replace") if sweep_path.is_file() else ""
    examined += 1
    if "plant_*.rb" not in sweep or "plant_*.py" not in sweep:
        errors.append("bin/sweep does not discover plant_*.py AND plant_*.rb (gap 111)")
    else:
        print("  ok sweep discovers py and rb plants")
    if "ModuleNotFoundError" in sweep and "skip" in sweep.lower() and "fail closed" not in sweep:
        errors.append("bin/sweep looks like it skips missing deps")
    if "UTF-8" not in sweep:
        errors.append("bin/sweep does not force a UTF-8 LANG")

    if sweep_path.is_file():
        examined += 1
        r = subprocess.run(
            [sys.executable, str(sweep_path), "--list"],
            cwd=str(root),
            capture_output=True,
            text=True,
            timeout=30,
        )
        if r.returncode != 0:
            errors.append("bin/sweep --list failed: %s" % (r.stderr or r.stdout)[:200])
        else:
            lines = [ln.strip() for ln in r.stdout.splitlines() if ln.strip()]
            if not lines:
                errors.append("bin/sweep --list is empty")
            py_p = [ln for ln in lines if ln.endswith(".py") and Path(ln).name.startswith("plant_")]
            rb_p = [ln for ln in lines if ln.endswith(".rb") and Path(ln).name.startswith("plant_")]
            ck = [ln for ln in lines if Path(ln).name.startswith("check_")]
            if not py_p:
                errors.append("sweep --list has 0 plant_*.py")
            if not rb_p:
                errors.append("sweep --list has 0 plant_*.rb")
            if not ck:
                errors.append("sweep --list has 0 check_*.py")
            print("  ok sweep --list %d jobs" % len(lines))

    excl_path = root / EXCL
    if excl_path.is_file():
        examined += 1
        try:
            data = json.loads(excl_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            errors.append("exclusions not JSON: %s" % e)
            data = {}
        for row in data.get("exclusions") or []:
            rel = (row.get("path") or "").strip()
            because = (row.get("because") or "").strip()
            if not rel or not because:
                errors.append("exclusion missing path or because")
                continue
            if not (root / rel).is_file():
                errors.append("exclusion matches nothing: %s" % rel)
            if ".github/workflows/" not in because:
                errors.append("exclusion %s because does not name a workflow" % rel)

    hook_path = root / HOOK
    hook = hook_path.read_text(encoding="utf-8", errors="replace") if hook_path.is_file() else ""
    examined += 1
    if "refs/heads/main" not in hook:
        errors.append("pre-push does not gate refs/heads/main")
    if "bin/sweep" not in hook:
        errors.append("pre-push does not run bin/sweep")
    if "MM_SWEEP_OVERRIDE" not in hook:
        errors.append("pre-push has no MM_SWEEP_OVERRIDE hatch")
    else:
        if "because:" not in hook:
            errors.append("override hatch does not require because:")
        if "sweep-overrides.jsonl" not in hook:
            errors.append("override hatch does not record to sweep-overrides.jsonl")
        print("  ok pre-push hatch is recorded")

    wf_path = root / WORKFLOW
    wf = wf_path.read_text(encoding="utf-8", errors="replace") if wf_path.is_file() else ""
    examined += 1
    if "bin/sweep" not in wf:
        errors.append("main-green.yml does not run bin/sweep")
    if "tooling/shacl/requirements.txt" not in wf:
        errors.append("main-green.yml does not install rdflib (fail closed)")
    if "LANG: en_US.UTF-8" not in wf and "LANG:en_US.UTF-8" not in wf:
        errors.append("main-green.yml does not set LANG")
    if "core.hooksPath" not in wf:
        errors.append("main-green.yml does not set core.hooksPath")
    if "branches: [ main ]" not in wf and "branches: [main]" not in wf:
        errors.append("main-green.yml does not run on push to main")

    git_dir = root / ".git"
    if git_dir.exists():
        examined += 1
        hp = git_config(root, "core.hooksPath")
        if hp is None:
            errors.append("git config unavailable")
        elif hp.rstrip("/") != "tooling/githooks":
            errors.append("core.hooksPath is %r, want tooling/githooks (run bin/install-hooks)" % hp)
        else:
            print("  ok core.hooksPath %s" % hp)

    populated, pop = emit_population(examined)
    if not populated:
        return 1
    if errors:
        for e in errors:
            print("FAIL: %s" % e, file=sys.stderr)
        print(json.dumps({"gate": "main-green", "status": "fail", "population": pop, "errors": errors}, indent=2))
        return 1
    print("OK main-green (%d examined)" % examined)
    return 0


if __name__ == "__main__":
    sys.exit(main())
