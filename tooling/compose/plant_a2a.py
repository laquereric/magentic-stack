#!/usr/bin/env python3
"""Plants for ADR 0066 / 0068. Empty CHECK_ROOT, dropping a2a.back.rpc
from the harness, serving a well-known Card from the intrapod binding,
preferring NATS on the internet Card, or dropping the well-known route
must fail.
"""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/compose/check_a2a.py"


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


def copy_a2a(dest: Path) -> None:
    files = (
        Path("gems/rails-cpcp/lib/rails_cpcp/a2a_binding.rb"),
        Path("gems/rails-cpcp/lib/rails_cpcp/a2a_internet.rb"),
        Path("runtimes/mind-pod/app/app/controllers/a2a_internet_controller.rb"),
        Path("runtimes/mind-pod/app/config/routes.rb"),
        Path("runtimes/mind-pod/mind/harness.py"),
        Path("runtimes/mind-pod/mind/mind_a2a.py"),
    )
    for rel in files:
        p = dest / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text((ROOT / rel).read_text(encoding="utf-8"), encoding="utf-8")


def main():
    rows = []
    ok = True
    r = run()
    ok = note(rows, "clean", r.returncode == 0, "exit %d" % r.returncode) and ok
    r = run({"CHECK_ROOT": ""})
    ok = note(rows, "empty-root", r.returncode != 0, "exit %d" % r.returncode) and ok

    with tempfile.TemporaryDirectory(prefix="a2a-drop-") as raw:
        d = Path(raw)
        copy_a2a(d)
        h = d / "runtimes/mind-pod/mind/harness.py"
        h.write_text(h.read_text(encoding="utf-8").replace("a2a.back.rpc", "cpcp.back.rpc"), encoding="utf-8")
        r = run({"CHECK_ROOT": str(d)})
        ok = note(rows, "drop-subject-fails", r.returncode != 0, "exit %d" % r.returncode) and ok

    with tempfile.TemporaryDirectory(prefix="a2a-http-") as raw:
        d = Path(raw)
        copy_a2a(d)
        rb = d / "gems/rails-cpcp/lib/rails_cpcp/a2a_binding.rb"
        rb.write_text(
            rb.read_text(encoding="utf-8").replace(
                '"preferredTransport" => "NATS"',
                '"preferredTransport" => "HTTP", "well_known" => "/.well-known/agent-card.json"',
            ),
            encoding="utf-8",
        )
        r = run({"CHECK_ROOT": str(d)})
        ok = note(rows, "http-card-fails", r.returncode != 0, "exit %d" % r.returncode) and ok

    with tempfile.TemporaryDirectory(prefix="a2a-inet-nats-") as raw:
        d = Path(raw)
        copy_a2a(d)
        inet = d / "gems/rails-cpcp/lib/rails_cpcp/a2a_internet.rb"
        inet.write_text(
            inet.read_text(encoding="utf-8").replace(
                '"preferredTransport" => "HTTP"',
                '"preferredTransport" => "NATS"',
            ),
            encoding="utf-8",
        )
        r = run({"CHECK_ROOT": str(d)})
        ok = note(rows, "internet-nats-card-fails", r.returncode != 0, "exit %d" % r.returncode) and ok

    with tempfile.TemporaryDirectory(prefix="a2a-drop-wk-") as raw:
        d = Path(raw)
        copy_a2a(d)
        rt = d / "runtimes/mind-pod/app/config/routes.rb"
        rt.write_text(
            rt.read_text(encoding="utf-8").replace(
                'get "/.well-known/agent-card.json", to: "a2a_internet#card"',
                "",
            ),
            encoding="utf-8",
        )
        r = run({"CHECK_ROOT": str(d)})
        ok = note(rows, "drop-well-known-fails", r.returncode != 0, "exit %d" % r.returncode) and ok

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant a2a: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
