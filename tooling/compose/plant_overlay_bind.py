#!/usr/bin/env python3
"""Plants for check_overlay_bind.py.

The load-bearing plant is `session-loopback`: it restores the exact defect that
cost gate-session-cycle its whole history -- an overlay publishing 3000:3000
while leaving BACK on the base's HTTP_BIND=127.0.0.1 -- and the checker must go
red on it.

`base-already-open` is its opposite and matters just as much. It removes the
overlay's line but flips the BASE to 0.0.0.0, so the effective value is still
right. A checker that merely grepped the overlay for a literal HTTP_BIND would
fail this tree and be wrong. Compose merges; the check has to merge too.

Every mutation ASSERTS THAT IT BIT before the checker is run. A plant that
silently no-ops because a string moved is a plant that reports the checker is
fine when nothing was ever planted -- which is how plants lie.
"""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/compose/check_overlay_bind.py"
BASE_REL = "runtimes/mind-pod/docker-compose.yml"
TEST_REL = "runtimes/mind-pod/test"


def run(env=None) -> subprocess.CompletedProcess:
    e = os.environ.copy()
    if env:
        e.update(env)
    return subprocess.run(
        [sys.executable, str(CHECKER)], cwd=str(ROOT), env=e,
        capture_output=True, text=True,
    )


def note(rows, name, passed, detail):
    rows.append((name, passed, detail))
    return passed


def write_tree(root: Path, base_text: str, overlays: dict) -> None:
    (root / "runtimes/mind-pod").mkdir(parents=True)
    (root / BASE_REL).write_text(base_text, encoding="utf-8")
    td = root / TEST_REL
    td.mkdir(parents=True)
    for name, text in overlays.items():
        (td / name).write_text(text, encoding="utf-8")


def main() -> int:
    rows = []
    ok = True

    r = run()
    ok = note(rows, "clean", r.returncode == 0, "exit %d" % r.returncode) and ok
    r = run({"CHECK_ROOT": ""})
    ok = note(rows, "empty-root", r.returncode != 0, "exit %d" % r.returncode) and ok

    base = (ROOT / BASE_REL).read_text(encoding="utf-8")
    session = (ROOT / TEST_REL / "docker-compose.session.yml").read_text(encoding="utf-8")

    # The historical defect: publish the port, inherit loopback.
    stripped = session.replace('    environment:\n      HTTP_BIND: "0.0.0.0"\n', "", 1)
    if stripped == session:
        ok = note(rows, "session-loopback", False,
                  "MUTATION DID NOT BITE: HTTP_BIND block not found in session overlay") and ok
    else:
        with tempfile.TemporaryDirectory(prefix="overlay-bind-loopback-") as raw:
            d = Path(raw)
            write_tree(d, base, {"docker-compose.session.yml": stripped})
            r = run({"CHECK_ROOT": str(d)})
            ok = note(rows, "session-loopback", r.returncode != 0,
                      "exit %d" % r.returncode) and ok

    # Same overlay, but the base already binds 0.0.0.0 -> effective value is
    # correct and the checker must NOT fail.
    open_base = base.replace('ROLE: back, PORT: "3000", HTTP_BIND: "127.0.0.1"',
                             'ROLE: back, PORT: "3000", HTTP_BIND: "0.0.0.0"', 1)
    if open_base == base:
        ok = note(rows, "base-already-open", False,
                  "MUTATION DID NOT BITE: back HTTP_BIND not found in base") and ok
    elif stripped == session:
        ok = note(rows, "base-already-open", False,
                  "skipped: overlay mutation did not bite") and ok
    else:
        with tempfile.TemporaryDirectory(prefix="overlay-bind-openbase-") as raw:
            d = Path(raw)
            write_tree(d, open_base, {"docker-compose.session.yml": stripped})
            r = run({"CHECK_ROOT": str(d)})
            ok = note(rows, "base-already-open", r.returncode == 0,
                      "exit %d (merged value is 0.0.0.0)" % r.returncode) and ok

    # No overlay publishes a rails role -> empty population is not a pass.
    with tempfile.TemporaryDirectory(prefix="overlay-bind-empty-") as raw:
        d = Path(raw)
        write_tree(d, base, {"docker-compose.session.yml":
                             "services:\n  graph:\n    ports: [\"7878:7878\"]\n"})
        r = run({"CHECK_ROOT": str(d)})
        ok = note(rows, "empty-population", r.returncode != 0, "exit %d" % r.returncode) and ok

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant overlay-bind: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
