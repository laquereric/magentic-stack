#!/usr/bin/env python3
"""Plants for gap 109. Overlap, owner-guess, 200-on-infra, controller flip.
Restores files.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/cpcp/check_cpcp_http_status.py"
CONTRACT = ROOT / "tooling/cpcp/cpcp_http_status.json"
CONTROLLER = ROOT / "gems/rails-cpcp/app/controllers/rails_cpcp/rpc_controller.rb"


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


def class_row(data, cid):
    return next(r for r in data["classes"] if r["id"] == cid)


def main():
    rows = []
    ok = True
    r = run()
    ok = note(rows, "clean", r.returncode == 0, "exit %d" % r.returncode) and ok
    r = run({"CHECK_ROOT": ""})
    ok = note(rows, "empty-root", r.returncode != 0, "exit %d" % r.returncode) and ok

    orig_c = CONTRACT.read_text(encoding="utf-8")
    try:
        data = json.loads(orig_c)
        class_row(data, "grounding")["http_status"] = 422
        CONTRACT.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        r = run()
        ok = note(rows, "grounding-as-422-fails", r.returncode != 0,
                  "exit %d" % r.returncode) and ok
    finally:
        CONTRACT.write_text(orig_c, encoding="utf-8")

    orig_c = CONTRACT.read_text(encoding="utf-8")
    try:
        data = json.loads(orig_c)
        class_row(data, "admission")["failure_layer"] = "domain"
        class_row(data, "admission")["owner_call"] = False
        CONTRACT.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        r = run()
        ok = note(rows, "admission-layer-guess-fails", r.returncode != 0,
                  "exit %d" % r.returncode) and ok
    finally:
        CONTRACT.write_text(orig_c, encoding="utf-8")

    orig_c = CONTRACT.read_text(encoding="utf-8")
    try:
        data = json.loads(orig_c)
        class_row(data, "outbox_not_installed")["http_status"] = 200
        CONTRACT.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        r = run()
        ok = note(rows, "200-on-infra-fails", r.returncode != 0,
                  "exit %d" % r.returncode) and ok
    finally:
        CONTRACT.write_text(orig_c, encoding="utf-8")

    orig_c = CONTRACT.read_text(encoding="utf-8")
    try:
        data = json.loads(orig_c)
        data["implemented"] = True
        CONTRACT.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        r = run()
        ok = note(rows, "implemented-true-fails", r.returncode != 0,
                  "exit %d" % r.returncode) and ok
    finally:
        CONTRACT.write_text(orig_c, encoding="utf-8")

    orig_c = CONTRACT.read_text(encoding="utf-8")
    try:
        data = json.loads(orig_c)
        class_row(data, "graph_unreachable")["retryable"] = True
        CONTRACT.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        r = run()
        ok = note(rows, "generic-503-retry-fails", r.returncode != 0,
                  "exit %d" % r.returncode) and ok
    finally:
        CONTRACT.write_text(orig_c, encoding="utf-8")

    orig_rb = CONTROLLER.read_text(encoding="utf-8")
    try:
        planted = orig_rb.replace("status: :ok", "status: :unprocessable_entity", 1)
        if planted == orig_rb:
            ok = note(rows, "controller-flip-edit", False, "could not plant") and ok
        else:
            CONTROLLER.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "controller-flip-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        CONTROLLER.write_text(orig_rb, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant cpcp-http-status: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
