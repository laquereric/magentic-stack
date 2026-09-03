#!/usr/bin/env python3
"""Plants for gap 104. Empty CHECK_ROOT, bare urlopen, URLError collapse.
Restores files.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/cpcp/check_urlopen_envelope.py"
HARNESS = ROOT / "runtimes/mind-pod/mind/harness.py"


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

    orig = HARNESS.read_text(encoding="utf-8")
    try:
        planted = orig.replace(
            "    try:\n        with urllib.request.urlopen(req, timeout=30) as r:\n"
            "            return json.loads(r.read().decode())\n"
            "    except urllib.error.HTTPError as e:\n"
            "        return json.loads(e.read().decode())\n",
            "    with urllib.request.urlopen(req, timeout=30) as r:\n"
            "        return json.loads(r.read().decode())\n",
            1,
        )
        if planted == orig:
            ok = note(rows, "bare-edit", False, "could not plant") and ok
        else:
            HARNESS.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "bare-urlopen-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        HARNESS.write_text(orig, encoding="utf-8")

    try:
        planted = orig.replace(
            "    except urllib.error.HTTPError as e:\n"
            "        return json.loads(e.read().decode())\n",
            "    except urllib.error.URLError as e:\n"
            "        return json.loads(getattr(e, 'read', lambda: b'{}')())\n",
            1,
        )
        if planted == orig:
            ok = note(rows, "collapse-edit", False, "could not plant") and ok
        else:
            HARNESS.write_text(planted, encoding="utf-8")
            r = run()
            ok = note(rows, "urlerror-collapse-fails", r.returncode != 0,
                      "exit %d" % r.returncode) and ok
    finally:
        HARNESS.write_text(orig, encoding="utf-8")

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant urlopen-envelope: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
