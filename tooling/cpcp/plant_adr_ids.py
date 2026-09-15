#!/usr/bin/env python3
"""Plants for check_adr_ids. Proves the gate fails when it should.

Both plants reproduce a collision that actually happened, five days apart:

  duplicate-id        two ADRs claiming 0070 -- monty and never-persist
  filename-disagrees  the half of a renumber that is easy to forget, where the
                      file moves and the field does not

Restores every file it touches.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/cpcp/check_adr_ids.py"
ADR_DIR = ROOT / "docs/adr"
PROBE = ADR_DIR / "0099-planted-duplicate.md"


def run():
    env = os.environ.copy()
    env.pop("CHECK_ROOT", None)
    return subprocess.run([sys.executable, str(CHECKER)], cwd=str(ROOT), env=env,
                          capture_output=True, text=True, timeout=300)


def main() -> int:
    rows: list[tuple[str, bool, str]] = []
    ok = True

    r = run()
    rows.append(("clean", r.returncode == 0, "exit %d" % r.returncode))
    ok = (r.returncode == 0) and ok

    victim = sorted(ADR_DIR.glob("00*.md"))[0]
    taken = victim.name[:4]

    # THE COLLISION ITSELF. A second file claiming an id that is already held.
    try:
        PROBE.write_text(
            '---\nid: "%s"\ntitle: Planted duplicate\nstatus: proposed\n'
            'date: 2026-09-15\nsubject_kind: doctrine\nsubject: plant\n---\n\n'
            '# ADR %s planted\n' % (taken, taken),
            encoding="utf-8",
        )
        r = run()
        caught = r.returncode != 0 and "is claimed by" in (r.stdout + r.stderr)
        rows.append(("duplicate-id", caught, "exit %d" % r.returncode))
        ok = caught and ok
    finally:
        PROBE.unlink(missing_ok=True)

    # THE HALF-DONE RENUMBER. File moved, field not -- or the reverse. A
    # directory listing reads correct and every consumer reads wrong.
    orig = victim.read_text(encoding="utf-8")
    try:
        victim.write_text(orig.replace('id: "%s"' % taken, 'id: "0999"', 1), encoding="utf-8")
        r = run()
        caught = r.returncode != 0 and "the filename says" in (r.stdout + r.stderr)
        rows.append(("filename-disagrees", caught, "exit %d" % r.returncode))
        ok = caught and ok
    finally:
        victim.write_text(orig, encoding="utf-8")

    # An ADR with no id at all cannot be checked for collision, and silence
    # about it would be a hole rather than a pass.
    try:
        victim.write_text(orig.replace('id: "%s"\n' % taken, "", 1), encoding="utf-8")
        r = run()
        caught = r.returncode != 0 and "has no `id:`" in (r.stdout + r.stderr)
        rows.append(("missing-id", caught, "exit %d" % r.returncode))
        ok = caught and ok
    finally:
        victim.write_text(orig, encoding="utf-8")

    r = run()
    rows.append(("restored", r.returncode == 0, "exit %d" % r.returncode))
    ok = (r.returncode == 0) and ok

    for name, passed, detail in rows:
        print("  %s %s -- %s" % ("ok" if passed else "FAIL", name, detail))
    print("population: %d examined, 0 skipped" % len(rows))
    print("plant adr-ids: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
