#!/usr/bin/env python3
"""Plants for gap 15. Inline table, dropped discovery, config egress, dual home.
Restores files.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/cpcp/check_config_catalog.py"
MJS = ROOT / "runtimes/switch/catalog.mjs"
DISCOVERY = ROOT / "runtimes/switch/discovery.mjs"
CTRL = ROOT / "runtimes/mind-pod/app/app/controllers/config_admin/catalog_controller.rb"
DOCKER = ROOT / "runtimes/switch/Dockerfile"
SWITCH_COPY = ROOT / "runtimes/switch/llm_catalog.json"


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

    orig = MJS.read_text(encoding="utf-8")
    try:
        MJS.write_text(
            orig + "\nexport const CATALOG = Object.freeze({\n  planted: { models: [] },\n});\n",
            encoding="utf-8",
        )
        r = run()
        ok = note(rows, "inline-table-fails", r.returncode != 0,
                  "exit %d" % r.returncode) and ok
    finally:
        MJS.write_text(orig, encoding="utf-8")

    orig_d = DISCOVERY.read_text(encoding="utf-8")
    try:
        DISCOVERY.unlink()
        r = run()
        ok = note(rows, "dropped-discovery-fails", r.returncode != 0,
                  "exit %d" % r.returncode) and ok
    finally:
        DISCOVERY.write_text(orig_d, encoding="utf-8")

    orig_c = CTRL.read_text(encoding="utf-8")
    try:
        planted = orig_c.replace(
            "def index",
            "def index\n    token = state.keys[vendorId]\n    egress(token)\n",
            1,
        )
        if planted == orig_c:
            ok = note(rows, "egress-edit", False, "could not plant") and ok
        else:
            CTRL.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "config-egress-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        CTRL.write_text(orig_c, encoding="utf-8")

    try:
        SWITCH_COPY.write_text('{"owned_by":"switch","vendors":{}}\n', encoding="utf-8")
        r = run()
        ok = note(rows, "dual-home-fails", r.returncode != 0,
                  "exit %d" % r.returncode) and ok
    finally:
        if SWITCH_COPY.exists():
            SWITCH_COPY.unlink()

    orig_dk = DOCKER.read_text(encoding="utf-8")
    try:
        planted = orig_dk.replace(
            "COPY runtimes/mind-pod/app/config/llm_catalog.json /switch/llm_catalog.json\n",
            "",
            1,
        )
        if planted == orig_dk:
            ok = note(rows, "dockerfile-edit", False, "could not plant") and ok
        else:
            DOCKER.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "dockerfile-uncopied-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        DOCKER.write_text(orig_dk, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant config-catalog: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
