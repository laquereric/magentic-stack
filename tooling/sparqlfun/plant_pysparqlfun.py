#!/usr/bin/env python3
"""Plants for check_pysparqlfun. Proves the gate fails when it should.

The plants that matter most put back the two failures these designs exist to
prevent, and both are silent when they happen:

  query-crosses-the-seam   a caller sends SPARQL and it runs. An agent that can
                           send arbitrary SPARQL can read any principal's rows,
                           and nothing about the response says so.
  clue-carries-the-prompt  the clue stops being an opaque name, so the routing
                           decision now depends on payload -- ADR 0019's
                           content-blind router has read the prompt.

Restores every file it touches.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/sparqlfun/check_pysparqlfun.py"
PKG = ROOT / "runtimes/mind-pod/mind/pysparqlfun"
SEAM = PKG / "seam.py"
CAPTURE = PKG / "capture.py"
CLUE = PKG / "clue.py"
CAPTURE_JSON = PKG / "captures/prior_contacts.json"


def run():
    env = os.environ.copy()
    env.pop("CHECK_ROOT", None)
    # __pycache__ would serve the pre-plant bytecode back and every plant would
    # "pass" against code that was never mutated -- a planter measuring nothing.
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    return subprocess.run([sys.executable, str(CHECKER)], cwd=str(ROOT), env=env,
                          capture_output=True, text=True, timeout=600)


def plant(rows, name, path, mutate):
    orig = path.read_text(encoding="utf-8")
    try:
        planted = mutate(orig)
        if planted == orig:
            rows.append((name, False, "could not plant -- the text it targets is gone"))
            return False
        path.write_text(planted, encoding="utf-8")
        r = run()
        rows.append((name, r.returncode != 0, "exit %d" % r.returncode))
        return r.returncode != 0
    finally:
        path.write_text(orig, encoding="utf-8")


def main() -> int:
    rows: list[tuple[str, bool, str]] = []
    ok = True

    r = run()
    rows.append(("clean", r.returncode == 0, "exit %d" % r.returncode))
    ok = (r.returncode == 0) and ok

    # THE GRANT. A query crosses the seam and runs.
    ok = plant(rows, "query-crosses-the-seam", SEAM,
               lambda t: t.replace("QUERY_PARAMS = (", "QUERY_PARAMS = ()  # (")) and ok

    # Worse than refusing: honoured in appearance only.
    ok = plant(rows, "query-silently-ignored", SEAM,
               lambda t: t.replace(
                   '            return refuse(\n                "raw_query_refused",',
                   '            continue\n            return refuse(\n                "raw_query_refused",')) and ok

    # THE PRINCIPAL. The argument wins instead of being refused.
    ok = plant(rows, "argument-overrides-the-frame", SEAM,
               lambda t: t.replace(
                   'if key in params and str(params[key]) != user:',
                   'if False and key in params and str(params[key]) != user:')) and ok

    # The frame stops being required.
    ok = plant(rows, "anonymous-frame-allowed", SEAM,
               lambda t: t.replace(
                   'if not isinstance(user, str) or not user.strip():',
                   'if False:')) and ok

    # user_id stops being bound, so a scoped capture answers for whoever.
    ok = plant(rows, "user-id-not-bound", SEAM,
               lambda t: t.replace('bindings = {"user_id": user, "id": event_id}',
                                   'bindings = {"id": event_id}')) and ok

    # The answer stops saying which corpus position it used, so no result can be
    # re-checked and determinism becomes unfalsifiable.
    ok = plant(rows, "position-not-recorded", SEAM,
               lambda t: t.replace("at=position, scoped=cap.scoped", "at=None, scoped=cap.scoped")) and ok

    # A missing store binding reports zero rows instead of refusing.
    ok = plant(rows, "no-store-reports-empty", SEAM,
               lambda t: t.replace(
                   '    if execute is None:\n        return refuse(\n            "graph_unreachable",',
                   '    if execute is None:\n        return ok(function=cap.name, id=event_id, at=position, result=[])\n'
                   '    if False:\n        return refuse(\n            "graph_unreachable",')) and ok

    # An unknown function falls back instead of refusing by name.
    ok = plant(rows, "unknown-function-falls-back", SEAM,
               lambda t: t.replace(
                   '    if cap is None:\n        return refuse(\n            "unknown_function",',
                   '    if cap is None:\n        cap = next(iter(registry.captures.values()))\n'
                   '    if False:\n        return refuse(\n            "unknown_function",')) and ok

    # LOAD-TIME RULES. A scoped capture with no user_id binding loads.
    ok = plant(rows, "scoped-without-binding-loads", CAPTURE,
               lambda t: t.replace("if self.scoped and not USER_BINDING.search(body):",
                                   "if False:")) and ok

    # A capture may call a model at request time.
    ok = plant(rows, "sampling-allowed-in-capture", CAPTURE,
               lambda t: t.replace("SAMPLING_MARKERS = (", "SAMPLING_MARKERS = ()  # (")) and ok

    # A registry that failed to load looks like an empty one.
    ok = plant(rows, "load-failure-looks-empty", SEAM,
               lambda t: t.replace("            return cls(load_error=(e.reason, e.because))",
                                   "            return cls()")) and ok

    # REPLAY. A drifted store passes.
    ok = plant(rows, "replay-ignores-drift", SEAM,
               lambda t: t.replace('if got != example["expected"]:', "if False:")) and ok

    # A capture whose examples no longer hold: the gate must catch it through
    # replay rather than through the file being obviously edited.
    ok = plant(rows, "capture-examples-drift", CAPTURE_JSON,
               lambda t: t.replace('"expected": [["contact:2", "2026-09-02"], ["contact:1", "2026-09-01"]]',
                                   '"expected": [["contact:2", "2026-09-02"]]')) and ok

    # THE CLUE. Long enough to carry a prompt.
    ok = plant(rows, "clue-carries-the-prompt", CLUE,
               lambda t: t.replace("MAX_LEN = 72", "MAX_LEN = 100_000")) and ok

    # The grammar stops being the content rule.
    ok = plant(rows, "clue-grammar-opened", CLUE,
               lambda t: t.replace(
                   r'TOKEN = re.compile(r"\A(select|author):([a-z0-9]([a-z0-9._-]{0,62}[a-z0-9])?)\Z")',
                   r'TOKEN = re.compile(r".*", re.S)')) and ok

    # THE SELECTOR AUTHORS.
    ok = plant(rows, "selector-may-author", CLUE,
               lambda t: t.replace('if capability != "select":', "if False:")) and ok

    r = run()
    rows.append(("restored", r.returncode == 0, "exit %d" % r.returncode))
    ok = (r.returncode == 0) and ok

    for name, passed, detail in rows:
        print("  %s %s -- %s" % ("ok" if passed else "FAIL", name, detail))
    print("population: %d examined, 0 skipped" % len(rows))
    print("plant pysparqlfun: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
