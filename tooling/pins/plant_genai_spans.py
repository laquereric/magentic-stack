#!/usr/bin/env python3
"""Plant: dropping gen_ai.operation.name or wiring must fail. Restores files."""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/pins/check_genai_spans.py"
SWITCH = ROOT / "runtimes/switch/genai_span.mjs"
DISP = ROOT / "gems/rails-cpcp/lib/rails_cpcp/dispatcher.rb"


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


def main() -> int:
    rows = []
    ok = True
    r = run()
    ok = note(rows, "clean", r.returncode == 0, "exit %d" % r.returncode) and ok
    r = run({"CHECK_ROOT": ""})
    ok = note(rows, "empty-root", r.returncode != 0, "exit %d" % r.returncode) and ok

    orig = SWITCH.read_text(encoding="utf-8")
    try:
        SWITCH.write_text(orig.replace("gen_ai.operation.name", "custom.op"), encoding="utf-8")
        r = run()
        ok = note(rows, "operation-renamed-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        SWITCH.write_text(orig, encoding="utf-8")

    orig_d = DISP.read_text(encoding="utf-8")
    try:
        DISP.write_text(orig_d.replace("GenaiSpan.around", "passthrough"), encoding="utf-8")
        r = run()
        ok = note(rows, "dispatcher-unwired-fails", r.returncode != 0, "exit %d" % r.returncode) and ok
    finally:
        DISP.write_text(orig_d, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant genai-spans: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
