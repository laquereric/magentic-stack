#!/usr/bin/env python3
"""Plants for gap 7 oxigraph env gate. Empty CHECK_ROOT and a stripped
writer env must fail. Restores files.
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/compose/check_oxigraph_env.py"


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


def main():
    rows = []
    ok = True

    r = run()
    ok = note(rows, "clean", r.returncode == 0, "exit %d" % r.returncode) and ok

    r = run({"CHECK_ROOT": ""})
    ok = note(rows, "empty-root", r.returncode != 0, "exit %d" % r.returncode) and ok

    with tempfile.TemporaryDirectory(prefix="oxigraph-env-") as raw:
        d = Path(raw)
        dest = d / "runtimes" / "mind-pod" / "app" / "extract"
        dest.mkdir(parents=True)
        src = ROOT / "runtimes/mind-pod/app/extract/compose.yml"
        text = src.read_text(encoding="utf-8")
        planted = re.sub(r',\s*MM_OXIGRAPH_URL:\s*"[^"]*"', "", text)

        def env_mentions(blob):
            code = "\n".join(line.split("#", 1)[0] for line in blob.splitlines())
            return "MM_OXIGRAPH_URL" in code

        if planted == text or env_mentions(planted):
            ok = note(rows, "stripped-edit", False, "could not strip MM_OXIGRAPH_URL") and ok
        else:
            (dest / "compose.yml").write_text(planted, encoding="utf-8")
            r = run({"CHECK_ROOT": str(d)})
            ok = note(
                rows,
                "stripped-env",
                r.returncode != 0,
                "exit %d stderr=%s" % (r.returncode, (r.stderr or "").strip().splitlines()[-1:] or [""]),
            ) and ok

    with tempfile.TemporaryDirectory(prefix="oxigraph-env-front-") as raw:
        d = Path(raw)
        dest = d / "compose"
        dest.mkdir()
        (dest / "compose.yml").write_text(
            "\n".join([
                "services:",
                "  front:",
                '    environment: { ROLE: front, PORT: "3000" }',
                "  graph:",
                "    image: oxigraph/oxigraph",
                "",
            ]),
            encoding="utf-8",
        )
        r = run({"CHECK_ROOT": str(d)})
        ok = note(rows, "graph-no-writer", r.returncode == 0, "exit %d" % r.returncode) and ok

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant oxigraph-env: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
