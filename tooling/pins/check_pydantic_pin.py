#!/usr/bin/env python3
"""Fail if MIND's pydantic pin drifts from the manifest, or the pin is hollow.

docs/pydantic-upgrades.md rec 1. The version in
upstreams/manifests/pydantic.pin.json must be the version
runtimes/mind-pod/mind/requirements.txt installs, and the MIND
Dockerfile must install that file before NOOA. Empty CHECK_ROOT fails.
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

PIN = Path("upstreams/manifests/pydantic.pin.json")
REQ = Path("runtimes/mind-pod/mind/requirements.txt")
DOCKER = Path("runtimes/mind-pod/mind/Dockerfile")
AGENT = Path("runtimes/mind-pod/mind/mind_agent.py")
VER_RE = re.compile(r"^pydantic==([0-9][^#\s]*)", re.M)


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

    pin_path = root / PIN
    req_path = root / REQ
    docker_path = root / DOCKER
    agent_path = root / AGENT
    ok = True
    ok = check("pin-file", pin_path.is_file(), str(pin_path)) and ok
    ok = check("req-file", req_path.is_file(), str(req_path)) and ok
    ok = check("dockerfile", docker_path.is_file(), str(docker_path)) and ok
    ok = check("agent", agent_path.is_file(), str(agent_path)) and ok
    if not ok:
        print("FAIL: missing pin surface", file=sys.stderr)
        return 1

    data = json.loads(pin_path.read_text(encoding="utf-8"))
    ver = str(data.get("pinned_version") or "")
    rb = str(data.get("rollback_target") or "")
    ok = check("kind-pypi", data.get("kind") == "pypi", data.get("kind")) and ok
    ok = check("not-fork", data.get("fork") is False, data.get("fork")) and ok
    ok = check("version-set", bool(ver) and ver != "PENDING", ver) and ok
    ok = check("rollback-set", bool(rb) and rb != "PENDING" and rb != ver, rb) and ok

    req = req_path.read_text(encoding="utf-8")
    m = VER_RE.search(req)
    req_ver = m.group(1) if m else ""
    ok = check("req-pins-exact", req_ver == ver, "req=%s pin=%s" % (req_ver, ver)) and ok

    df = docker_path.read_text(encoding="utf-8")
    ok = check("dockerfile-copies-req", "COPY requirements.txt" in df, "COPY requirements.txt") and ok
    ok = check("dockerfile-installs-req", "-r /tmp/requirements.txt" in df or "-r requirements.txt" in df,
               "pip -r requirements.txt") and ok

    agent = agent_path.read_text(encoding="utf-8")
    ok = check("agent-imports-pydantic", "from pydantic import" in agent, "from pydantic import") and ok

    populated, _pop = emit_population(len(checks), skipped_reason="")
    if not populated:
        return 1
    print("check | ok | detail")
    print("------|----|--------")
    for name, passed, detail in checks:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    if not ok:
        print("pydantic-pin: FAIL", file=sys.stderr)
        return 1
    print("pydantic-pin: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
