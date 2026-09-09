#!/usr/bin/env python3
"""Plants for ADR 0065 nats gate. Empty CHECK_ROOT, dropping the nats
service, host-publishing :4222, and stripping MM_NATS_URL must fail.
Restores nothing in the live tree — plants run in tempfile CHECK_ROOT.
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/compose/check_nats.py"
SRC = ROOT / "runtimes/mind-pod/docker-compose.yml"


def run(env=None, cwd=None) -> subprocess.CompletedProcess:
    e = os.environ.copy()
    if env:
        e.update(env)
    return subprocess.run(
        [sys.executable, str(CHECKER)],
        cwd=str(cwd or ROOT),
        env=e,
        capture_output=True,
        text=True,
    )


def note(rows, name, passed, detail):
    rows.append((name, passed, detail))
    return passed


def write_compose(root: Path, text: str) -> None:
    dest = root / "runtimes" / "mind-pod"
    dest.mkdir(parents=True)
    (dest / "docker-compose.yml").write_text(text, encoding="utf-8")
    extract = dest / "app" / "extract"
    extract.mkdir(parents=True)
    (extract / "compose.yml").write_text(text, encoding="utf-8")


def main():
    rows = []
    ok = True

    r = run()
    ok = note(rows, "clean", r.returncode == 0, "exit %d" % r.returncode) and ok

    r = run({"CHECK_ROOT": ""})
    ok = note(rows, "empty-root", r.returncode != 0, "exit %d" % r.returncode) and ok

    orig = SRC.read_text(encoding="utf-8")

    with tempfile.TemporaryDirectory(prefix="nats-drop-") as raw:
        d = Path(raw)
        dropped = re.sub(
            r"^  nats:\n(?:    .*\n)+",
            "",
            orig,
            count=1,
            flags=re.M,
        )
        write_compose(d, dropped)
        r = run({"CHECK_ROOT": str(d)})
        ok = note(rows, "drop-service-fails", r.returncode != 0, "exit %d" % r.returncode) and ok

    with tempfile.TemporaryDirectory(prefix="nats-ports-") as raw:
        d = Path(raw)
        planted = orig.replace(
            '    expose: [ "4222" ]',
            '    expose: [ "4222" ]\n    ports: [ "127.0.0.1:4222:4222" ]',
            1,
        )
        write_compose(d, planted)
        r = run({"CHECK_ROOT": str(d)})
        ok = note(rows, "publish-fails", r.returncode != 0, "exit %d" % r.returncode) and ok

    with tempfile.TemporaryDirectory(prefix="nats-env-") as raw:
        d = Path(raw)
        planted = orig.replace(', MM_NATS_URL: "nats://nats:4222"', "")
        planted = planted.replace('\n      MM_NATS_URL: "nats://nats:4222"', "")
        write_compose(d, planted)
        r = run({"CHECK_ROOT": str(d)})
        ok = note(rows, "stripped-env-fails", r.returncode != 0, "exit %d" % r.returncode) and ok

    with tempfile.TemporaryDirectory(prefix="nats-pin-") as raw:
        d = Path(raw)
        planted = re.sub(
            r"image: nats:2\.11\.16@sha256:[0-9a-f]+",
            "image: nats:2.11.16",
            orig,
        )
        write_compose(d, planted)
        r = run({"CHECK_ROOT": str(d)})
        ok = note(rows, "unpinned-fails", r.returncode != 0, "exit %d" % r.returncode) and ok

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant nats: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
