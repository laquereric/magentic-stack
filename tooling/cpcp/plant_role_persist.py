#!/usr/bin/env python3
"""Plants for row 8. Empty CHECK_ROOT, engine mount, BACK dials persist,
primary db:prepare on persist, missing PERSIST_DB_PATH, domain-store mount.
Restores files.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/cpcp/check_role_persist.py"
ROUTES = ROOT / "runtimes/mind-pod/app/config/routes.rb"
CLIENT = ROOT / "runtimes/mind-pod/app/app/services/back_cpcp_client.rb"
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
            'when "persist"',
            'when "persist"\n    mount RailsCpcp::Engine => "/_cpcp"',
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

    orig_c = CLIENT.read_text(encoding="utf-8")
    try:
        CLIENT.write_text(orig_c + "\n# http://persist:3000/_cpcp/rpc\n", encoding="utf-8")
        r = run()
        ok = note(rows, "back-dials-persist-fails", r.returncode != 0,
                  "exit %d" % r.returncode) and ok
    finally:
        CLIENT.write_text(orig_c, encoding="utf-8")

    orig_e = ENTRY.read_text(encoding="utf-8")
    try:
        planted = orig_e.replace(
            "    bundle exec rails db:migrate:persist\n",
            "    bundle exec rails db:prepare\n",
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

    orig_d = COMPOSE.read_text(encoding="utf-8")
    try:
        planted = orig_d.replace("PERSIST_DB_PATH: /persist-data/persist.sqlite3, ", "", 1)
        if planted == orig_d:
            ok = note(rows, "persist-db-edit", False, "could not plant") and ok
        else:
            COMPOSE.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "no-persist-db-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        COMPOSE.write_text(orig_d, encoding="utf-8")

    try:
        planted = orig_d.replace(
            'volumes: [ "persist-data:/persist-data" ]',
            'volumes: [ "persist-data:/persist-data", "mind-data:/data" ]',
            1,
        )
        if planted == orig_d:
            ok = note(rows, "persist-vol-edit", False, "could not plant") and ok
        else:
            COMPOSE.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "domain-mount-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        COMPOSE.write_text(orig_d, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant role-persist: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
