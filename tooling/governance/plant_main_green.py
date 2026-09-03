#!/usr/bin/env python3
"""Plants for row 114. Empty CHECK_ROOT, dropping the hook, dropping .rb
discovery, empty override accepted, workflow without sweep. Restores files.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/governance/check_main_green.py"
HOOK = ROOT / "tooling/githooks/pre-push"
SWEEP = ROOT / "bin/sweep"
WORKFLOW = ROOT / ".github/workflows/main-green.yml"
EXCL = ROOT / "tooling/governance/sweep_exclusions.json"
INSTALL = ROOT / "bin/install-hooks"


def run(env=None):
    e = os.environ.copy()
    e.pop("CHECK_ROOT", None)
    if env:
        e.update(env)
    return subprocess.run(
        [sys.executable, str(CHECKER)],
        cwd=str(ROOT),
        env=e,
        capture_output=True,
        text=True,
    )


def note(rows, name, passed, detail):
    rows.append((name, passed, detail))
    return passed


def main():
    rows = []
    ok = True
    r = run()
    ok = note(rows, "clean", r.returncode == 0, "exit %d" % r.returncode) and ok
    r = run({"CHECK_ROOT": ""})
    ok = note(rows, "empty-root", r.returncode != 0, "exit %d" % r.returncode) and ok

    orig_h = HOOK.read_text(encoding="utf-8")
    try:
        HOOK.write_text("# planted empty hook\n", encoding="utf-8")
        r = run()
        ok = note(rows, "drop-hook-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        HOOK.write_text(orig_h, encoding="utf-8")

    orig_s = SWEEP.read_text(encoding="utf-8")
    try:
        planted = orig_s.replace('"plant_*.rb"', '"plant_*.nope"')
        if planted == orig_s:
            ok = note(rows, "rb-edit", False, "could not plant") and ok
        else:
            SWEEP.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "drop-rb-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        SWEEP.write_text(orig_s, encoding="utf-8")

    try:
        planted = orig_h.replace("because:", "reason:")
        if planted == orig_h:
            ok = note(rows, "hatch-edit", False, "could not plant") and ok
        else:
            HOOK.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "silent-hatch-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        HOOK.write_text(orig_h, encoding="utf-8")

    orig_w = WORKFLOW.read_text(encoding="utf-8")
    try:
        planted = orig_w.replace("python3 bin/sweep", "echo skip")
        if planted == orig_w:
            ok = note(rows, "wf-edit", False, "could not plant") and ok
        else:
            WORKFLOW.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "drop-sweep-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        WORKFLOW.write_text(orig_w, encoding="utf-8")

    orig_i = INSTALL.read_text(encoding="utf-8")
    try:
        planted = orig_i.replace("python3 -m venv", "echo no-venv")
        if planted == orig_i:
            ok = note(rows, "venv-edit", False, "could not plant") and ok
        else:
            INSTALL.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "drop-venv-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        INSTALL.write_text(orig_i, encoding="utf-8")

    orig_s2 = SWEEP.read_text(encoding="utf-8")
    try:
        planted = orig_s2.replace("venv present but incomplete", "venv maybe fine")
        if planted == orig_s2:
            ok = note(rows, "rot-edit", False, "could not plant") and ok
        else:
            SWEEP.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "drop-rot-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        SWEEP.write_text(orig_s2, encoding="utf-8")

    orig_e = EXCL.read_text(encoding="utf-8")
    try:
        data = json.loads(orig_e)
        data["exclusions"] = [{
            "path": "tooling/does-not-exist.py",
            "because": "covered by .github/workflows/role-routes.yml",
        }]
        EXCL.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        r = run()
        ok = note(rows, "ghost-exclusion-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        EXCL.write_text(orig_e, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant main-green: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
