#!/usr/bin/env python3
"""Plants for row 18. Empty CHECK_ROOT, engine mount, RES in authority,
BACK dials bus, primary db:prepare on bus, missing BUS_DB_PATH,
mind-data rw on bus. Restores files.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/cpcp/check_role_bus.py"
ROUTES = ROOT / "runtimes/mind-pod/app/config/routes.rb"
SEAMS = ROOT / "tooling/cpcp/seam_authority.json"
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
            'when "bus"',
            'when "bus"\n    mount RailsCpcp::Engine => "/_cpcp"',
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

    orig_s = SEAMS.read_text(encoding="utf-8")
    try:
        data = json.loads(orig_s)
        for row in data.get("live") or []:
            if row.get("id") == "bus":
                row["authoritative_for"] = "RES metadata"
        SEAMS.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        r = run()
        ok = note(rows, "res-authority-fails", r.returncode != 0,
                  "exit %d" % r.returncode) and ok
    finally:
        SEAMS.write_text(orig_s, encoding="utf-8")

    orig_c = CLIENT.read_text(encoding="utf-8")
    try:
        CLIENT.write_text(orig_c + "\n# http://bus:3000/_cpcp/rpc\n", encoding="utf-8")
        r = run()
        ok = note(rows, "back-dials-bus-fails", r.returncode != 0,
                  "exit %d" % r.returncode) and ok
    finally:
        CLIENT.write_text(orig_c, encoding="utf-8")

    orig_e = ENTRY.read_text(encoding="utf-8")
    try:
        planted = orig_e.replace(
            "    bundle exec rails db:migrate:bus\n",
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
        planted = orig_d.replace(", BUS_DB_PATH: /bus-data/bus.sqlite3 }", " }", 1)
        if planted == orig_d:
            ok = note(rows, "bus-db-edit", False, "could not plant") and ok
        else:
            COMPOSE.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "no-bus-db-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        COMPOSE.write_text(orig_d, encoding="utf-8")

    try:
        planted = orig_d.replace('"mind-data:/data:ro"', '"mind-data:/data"', 1)
        if planted == orig_d:
            ok = note(rows, "bus-ro-edit", False, "could not plant") and ok
        else:
            COMPOSE.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "bus-rw-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        COMPOSE.write_text(orig_d, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant role-bus: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
