#!/usr/bin/env python3
"""Plants for check_perch_contract. Proves the gate fails when it should.

The interesting ones are the asymmetric pair: a contract that OMITS a live
operation is an undeclared wire surface, and a contract that KEEPS one the code
dropped is a promise nothing serves. A gate that catches only the first lets
the contract rot in the direction that reads as complete.

Restores every file it touches.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/perch/check_perch_contract.py"
FRAGMENT = ROOT / ".cpcp/cid/perch.json"
INIT = ROOT / "runtimes/mind-pod/app/config/initializers/rails_cpcp.rb"


def run():
    env = os.environ.copy()
    env.pop("CHECK_ROOT", None)
    return subprocess.run([sys.executable, str(CHECKER)], cwd=str(ROOT), env=env,
                          capture_output=True, text=True, timeout=300)


def plant(rows, name, path, mutate, marker=None):
    orig = path.read_text(encoding="utf-8")
    try:
        planted = mutate(orig)
        if planted == orig:
            rows.append((name, False, "could not plant -- the text it targets is gone"))
            return False
        path.write_text(planted, encoding="utf-8")
        r = run()
        caught = r.returncode != 0
        if marker:
            caught = caught and marker in (r.stdout + r.stderr)
        rows.append((name, caught, "exit %d" % r.returncode))
        return caught
    finally:
        path.write_text(orig, encoding="utf-8")


def drop_operation(text, name):
    doc = json.loads(text)
    doc["operations"] = [o for o in doc["operations"] if o["name"] != name]
    return json.dumps(doc, indent=2) + "\n"


def edit_operation(text, name, key, value):
    doc = json.loads(text)
    for o in doc["operations"]:
        if o["name"] == name:
            o[key] = value
    return json.dumps(doc, indent=2) + "\n"


def main() -> int:
    rows: list[tuple[str, bool, str]] = []
    ok = True

    r = run()
    rows.append(("clean", r.returncode == 0, "exit %d" % r.returncode))
    ok = (r.returncode == 0) and ok

    # An operation is live and the contract does not mention it.
    ok = plant(rows, "contract-omits-a-live-operation", FRAGMENT,
               lambda t: drop_operation(t, "perch.release"),
               "absent from the contract") and ok

    # The mirror, and the worse one: the code dropped it and the contract still
    # promises it.
    ok = plant(rows, "contract-promises-a-dead-operation", INIT,
               lambda t: t.replace('operation "perch.orphan.open"',
                                   'operation "perch.orphan.retired"'),
               "no longer declared in code") and ok

    # PUSH is an admission. Calling it PULL in the contract hides that.
    ok = plant(rows, "contract-downgrades-a-push", FRAGMENT,
               lambda t: edit_operation(t, "perch.release", "direction", "PULL"),
               "Direction is not cosmetic") and ok

    ok = plant(rows, "contract-params-drift", FRAGMENT,
               lambda t: edit_operation(t, "perch.slice.status", "params", ["uc_id"]),
               "contract params") and ok

    # An operation that cannot say how it says no is not specified.
    ok = plant(rows, "operation-declares-no-refusals", FRAGMENT,
               lambda t: edit_operation(t, "perch.slice.size", "refusals", []),
               "declares no refusals") and ok

    # A reason nothing can emit -- a caller would branch on it forever.
    ok = plant(rows, "contract-invents-a-refusal", FRAGMENT,
               lambda t: edit_operation(t, "perch.slice.size", "refusals", ["slice_looks_wrong"]),
               "in neither the gem's closed set") and ok

    # Identity as a wire param is the one that matters most: a caller that can
    # name itself can be anyone.
    ok = plant(rows, "actor-id-becomes-a-wire-param", INIT,
               lambda t: t.replace('params: %w[operationId group_key]',
                                   'params: %w[operationId group_key actor_id]'),
               "identity comes from the bearer") and ok

    ok = plant(rows, "push-loses-its-operation-id", INIT,
               lambda t: t.replace('params: %w[operationId group_key]',
                                   'params: %w[group_key]'),
               "not idempotent") and ok

    r = run()
    rows.append(("restored", r.returncode == 0, "exit %d" % r.returncode))
    ok = (r.returncode == 0) and ok

    print("plant_perch_contract:")
    for name, passed, detail in rows:
        print("  %s  %s  %s" % ("ok" if passed else "FAIL", name, detail))
    print("population: %d examined, 0 skipped" % len(rows))
    print("plant perch-contract: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
