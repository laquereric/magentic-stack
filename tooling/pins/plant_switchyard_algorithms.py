#!/usr/bin/env python3
"""Plants for row 11 v1 content-blind gate. Empty CHECK_ROOT, judge,
escalation, restoring routeQuery, publishing 4000. Restores files.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/pins/check_switchyard_algorithms.py"
TOML = ROOT / "gems/adapters/nemo-switchyard/content-blind.toml"
SERVER = ROOT / "runtimes/switch/server.mjs"
COMPOSE = ROOT / "runtimes/mind-pod/docker-compose.yml"


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

    orig_t = TOML.read_text(encoding="utf-8")
    try:
        planted = orig_t.replace('type = "random"', 'type = "llm_classifier"', 1)
        if planted == orig_t:
            ok = note(rows, "judge-edit", False, "could not plant") and ok
        else:
            TOML.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "judge-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        TOML.write_text(orig_t, encoding="utf-8")

    try:
        planted = orig_t.replace('type = "passthrough"', 'type = "stage_router"', 1)
        if planted == orig_t:
            ok = note(rows, "escalation-edit", False, "could not plant") and ok
        else:
            TOML.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "escalation-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        TOML.write_text(orig_t, encoding="utf-8")

    orig_s = SERVER.read_text(encoding="utf-8")
    try:
        planted = orig_s.replace(
            "import { parsePin } from './router.mjs';",
            "import { route as routeQuery, parsePin } from './router.mjs';",
            1,
        )
        if planted == orig_s:
            ok = note(rows, "router-edit", False, "could not plant") and ok
        else:
            SERVER.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "routequery-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        SERVER.write_text(orig_s, encoding="utf-8")

    orig_c = COMPOSE.read_text(encoding="utf-8")
    try:
        planted = orig_c.replace(
            '    expose: [ "8789", "8790" ]',
            '    expose: [ "8789", "8790" ]\n    ports: [ "13001:8790", "4000:4000" ]',
            1,
        )
        if planted == orig_c:
            ok = note(rows, "port-edit", False, "could not plant") and ok
        else:
            COMPOSE.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "publish-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        COMPOSE.write_text(orig_c, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant switchyard-algorithms: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
