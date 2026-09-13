#!/usr/bin/env python3
"""Plant: prepare pointing elsewhere, or dropping the gitignore, must fail."""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/pins/check_nooa_vendor.py"
PREPARE = ROOT / "runtimes/mind-pod/mind/bin/prepare"
GITIGNORE = ROOT / "runtimes/mind-pod/mind/.gitignore"
PIN = ROOT / "upstreams/manifests/nooa.pin.json"
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


def main() -> int:
    rows = []
    ok = True
    r = run()
    ok = (r.returncode == 0) and ok
    rows.append(("clean", r.returncode == 0, "exit %d" % r.returncode))
    r = run({"CHECK_ROOT": ""})
    ok = (r.returncode != 0) and ok
    rows.append(("empty-root", r.returncode != 0, "exit %d" % r.returncode))

    orig = PREPARE.read_text(encoding="utf-8")
    sub = json.loads(PIN.read_text(encoding="utf-8"))["submodule_path"]
    try:
        PREPARE.write_text(orig.replace(sub, "somewhere/else"), encoding="utf-8")
        r = run()
        ok = (r.returncode != 0) and ok
        rows.append(("wrong-src-fails", r.returncode != 0, "exit %d" % r.returncode))
    finally:
        PREPARE.write_text(orig, encoding="utf-8")

    orig_g = GITIGNORE.read_text(encoding="utf-8")
    try:
        GITIGNORE.write_text(
            "\n".join(ln for ln in orig_g.splitlines() if "nooa" not in ln) + "\n",
            encoding="utf-8",
        )
        r = run()
        ok = (r.returncode != 0) and ok
        rows.append(("gitignore-dropped-fails", r.returncode != 0, "exit %d" % r.returncode))
    finally:
        GITIGNORE.write_text(orig_g, encoding="utf-8")

    orig_c = COMPOSE.read_text(encoding="utf-8")
    try:
        COMPOSE.write_text(orig_c.replace("nooa_src", "somewhere_else"), encoding="utf-8")
        r = run()
        ok = (r.returncode != 0) and ok
        rows.append(("compose-context-stripped-fails", r.returncode != 0, "exit %d" % r.returncode))
    finally:
        COMPOSE.write_text(orig_c, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant nooa-vendor: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
