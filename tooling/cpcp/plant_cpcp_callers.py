#!/usr/bin/env python3
"""Plants for gap 59. Unclassified _cpcp/rpc site and empty CHECK_ROOT fail.
Does not leave files behind.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/cpcp/check_cpcp_callers.py"
INV = ROOT / "tooling/cpcp/cpcp_callers.json"


def run(env=None, cwd=None):
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


def main():
    rows = []
    ok = True
    env = os.environ.copy()
    env.pop("CHECK_ROOT", None)

    r = run(env)
    rows.append(("clean", r.returncode == 0, "exit %d" % r.returncode))
    ok = ok and r.returncode == 0

    r = run({**env, "CHECK_ROOT": ""})
    rows.append(("empty-root", r.returncode != 0, "exit %d" % r.returncode))
    ok = ok and r.returncode != 0

    orig = INV.read_text(encoding="utf-8")
    try:
        data = json.loads(orig)
        data["entries"] = [e for e in data["entries"] if "harness.py" not in e.get("file", "")]
        INV.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        r = run(env)
        hit = "UNCLASSIFIED" in (r.stderr or "") and "harness.py" in (r.stderr or "")
        rows.append(("drop-caller-fails", r.returncode != 0 and hit,
                     "exit %d hit=%s" % (r.returncode, hit)))
        ok = ok and r.returncode != 0 and hit
    finally:
        INV.write_text(orig, encoding="utf-8")

    with tempfile.TemporaryDirectory(prefix="gap59-") as tmp:
        tmp = Path(tmp)
        (tmp / "tooling" / "cpcp").mkdir(parents=True)
        (tmp / "tooling" / "cpcp" / "cpcp_callers.json").write_text(orig, encoding="utf-8")
        plant = tmp / "runtimes" / "mind-pod" / "mind"
        plant.mkdir(parents=True)
        (plant / "extra_client.py").write_text(
            'urllib.request.Request("http://back:3000/_cpcp/rpc")\n',
            encoding="utf-8",
        )
        r = run({**env, "CHECK_ROOT": str(tmp)})
        hit = "UNCLASSIFIED" in (r.stderr or "") and "extra_client.py" in (r.stderr or "")
        rows.append(("new-python-caller-fails", r.returncode != 0 and hit,
                     "exit %d hit=%s" % (r.returncode, hit)))
        ok = ok and r.returncode != 0 and hit

    print("plant | ok | detail")
    print("------|----|--------")
    for name, passed, detail in rows:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    print("plant cpcp-callers: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
