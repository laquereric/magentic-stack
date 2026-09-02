#!/usr/bin/env python3
"""Plants for ROLE=shape v1. Empty CHECK_ROOT, engine mount, empty
catalog ok:true, host-published port, db:prepare, false incomplete
reason. Restores files.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/compose/check_role_shape.py"
ROUTES = ROOT / "runtimes/mind-pod/app/config/routes.rb"
SURFACE = ROOT / "runtimes/mind-pod/app/app/services/shape_surface.rb"
ENTRY = ROOT / "runtimes/mind-pod/app/extract/entrypoint.sh"
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

    orig_r = ROUTES.read_text(encoding="utf-8")
    try:
        planted = orig_r.replace(
            'when "shape"',
            'when "shape"\n    mount RailsCpcp::Engine => "/_cpcp"',
            1,
        )
        if planted == orig_r:
            ok = note(rows, "engine-edit", False, "could not plant") and ok
        else:
            ROUTES.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "engine-mount-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        ROUTES.write_text(orig_r, encoding="utf-8")

    orig_s = SURFACE.read_text(encoding="utf-8")
    try:
        planted = orig_s.replace('"ok" => false', '"ok" => true', 1)
        if planted == orig_s:
            ok = note(rows, "empty-ok-edit", False, "could not plant") and ok
        else:
            SURFACE.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "empty-ok-true-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        SURFACE.write_text(orig_s, encoding="utf-8")

    try:
        planted = orig_s.replace(
            "P2-P8 and P10 protocol shapes are not in the pin",
            "shapes-level-8 is not in SHAPE_MAP",
            1,
        )
        if planted == orig_s:
            ok = note(rows, "false-reason-edit", False, "could not plant") and ok
        else:
            SURFACE.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "false-reason-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        SURFACE.write_text(orig_s, encoding="utf-8")

    orig_e = ENTRY.read_text(encoding="utf-8")
    try:
        planted = orig_e.replace(
            "  shape)\n    # Retrieval only. No domain DB.\n    exec bundle exec rails server -b 0.0.0.0 -p \"$PORT\"\n    ;;\n",
            "  shape)\n    bundle exec rails db:prepare\n    exec bundle exec rails server -b 0.0.0.0 -p \"$PORT\"\n    ;;\n",
            1,
        )
        if planted == orig_e:
            ok = note(rows, "db-edit", False, "could not plant") and ok
        else:
            ENTRY.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "db-prepare-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        ENTRY.write_text(orig_e, encoding="utf-8")

    orig_c = COMPOSE.read_text(encoding="utf-8")
    try:
        planted = orig_c.replace(
            "    environment: { ROLE: shape, PORT: \"3000\" }\n    expose: [ \"3000\" ]",
            "    environment: { ROLE: shape, PORT: \"3000\" }\n    expose: [ \"3000\" ]\n    ports: [ \"13004:3000\" ]",
            1,
        )
        if planted == orig_c:
            ok = note(rows, "ports-edit", False, "could not plant") and ok
        else:
            COMPOSE.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "host-publish-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        COMPOSE.write_text(orig_c, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant role-shape: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
