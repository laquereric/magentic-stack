#!/usr/bin/env python3
"""Plants for in-pod HTTP loopback bind. Empty CHECK_ROOT, exposing 3000
on vault, and binding vault to 0.0.0.0 must fail.
"""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/compose/check_http_bind.py"
SRC = ROOT / "runtimes/mind-pod/docker-compose.yml"


def run(env=None) -> subprocess.CompletedProcess:
    e = os.environ.copy()
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


def write_tree(root: Path, compose_text: str, entrypoint: str) -> None:
    dest = root / "runtimes/mind-pod"
    dest.mkdir(parents=True)
    (dest / "docker-compose.yml").write_text(compose_text, encoding="utf-8")
    extract = dest / "app/extract"
    extract.mkdir(parents=True)
    (extract / "compose.yml").write_text(compose_text, encoding="utf-8")
    (extract / "entrypoint.sh").write_text(entrypoint, encoding="utf-8")


def main():
    rows = []
    ok = True
    r = run()
    ok = note(rows, "clean", r.returncode == 0, "exit %d" % r.returncode) and ok
    r = run({"CHECK_ROOT": ""})
    ok = note(rows, "empty-root", r.returncode != 0, "exit %d" % r.returncode) and ok

    orig = SRC.read_text(encoding="utf-8")
    ep = (ROOT / "runtimes/mind-pod/app/extract/entrypoint.sh").read_text(encoding="utf-8")

    with tempfile.TemporaryDirectory(prefix="http-bind-expose-") as raw:
        d = Path(raw)
        planted = orig.replace(
            'HTTP_BIND: "127.0.0.1"\n    volumes: [ "../../.agent/vault:/vault" ]',
            'HTTP_BIND: "127.0.0.1"\n    volumes: [ "../../.agent/vault:/vault" ]\n    expose: [ "3000" ]',
            1,
        )
        write_tree(d, planted, ep)
        r = run({"CHECK_ROOT": str(d)})
        ok = note(rows, "vault-expose-fails", r.returncode != 0, "exit %d" % r.returncode) and ok

    with tempfile.TemporaryDirectory(prefix="http-bind-open-") as raw:
        d = Path(raw)
        planted = orig.replace('HTTP_BIND: "127.0.0.1"', 'HTTP_BIND: "0.0.0.0"', 1)
        write_tree(d, planted, ep)
        r = run({"CHECK_ROOT": str(d)})
        ok = note(rows, "in-pod-0.0.0.0-fails", r.returncode != 0, "exit %d" % r.returncode) and ok

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant http-bind: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
