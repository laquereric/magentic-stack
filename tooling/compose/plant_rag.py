#!/usr/bin/env python3
"""Plants for check_rag. Proves the gate fails when it should.

RagContainer.md names three plants by hand -- "a Cloud endpoint, a published
port, and a missing volume each fail" -- and each is here, plus the two that
cover the seam rather than the engine. A checker that has never been planted is
not a gate; it is a function nobody has watched refuse.

Restores every file it touches.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tooling/compose/check_rag.py"
COMPOSE = ROOT / "runtimes/mind-pod/app/extract/compose.yml"
ROUTES = ROOT / "runtimes/mind-pod/app/config/routes.rb"
ENTRYPOINT = ROOT / "runtimes/mind-pod/app/extract/entrypoint.sh"


def run():
    env = os.environ.copy()
    env.pop("CHECK_ROOT", None)
    return subprocess.run([sys.executable, str(CHECKER)], cwd=str(ROOT), env=env,
                          capture_output=True, text=True, timeout=300)


def plant(rows, name, path, mutate, marker):
    """Apply a mutation, expect the checker to refuse, then restore."""
    orig = path.read_text(encoding="utf-8")
    try:
        planted = mutate(orig)
        if planted == orig:
            rows.append((name, False, "could not plant"))
            return False
        path.write_text(planted, encoding="utf-8")
        r = run()
        caught = r.returncode != 0 and marker in (r.stdout + r.stderr)
        rows.append((name, caught, "exit %d" % r.returncode))
        return caught
    finally:
        path.write_text(orig, encoding="utf-8")


def main() -> int:
    rows: list[tuple[str, bool, str]] = []
    ok = True

    r = run()
    rows.append(("clean", r.returncode == 0, "exit %d" % r.returncode))
    ok = (r.returncode == 0) and ok

    # Named in the design doc.
    ok = plant(rows, "cloud-endpoint", COMPOSE,
               lambda t: t.replace('MILVUS_URL: "http://milvus:19530"',
                                   'MILVUS_URL: "https://in01-abc.aws.zillizcloud.com:19530"'),
               "Zilliz Cloud") and ok

    ok = plant(rows, "published-port", COMPOSE,
               lambda t: t.replace('    expose: [ "19530" ]',
                                   '    ports: [ "127.0.0.1:19530:19530" ]\n    expose: [ "19530" ]'),
               "host-published") and ok

    ok = plant(rows, "missing-volume", COMPOSE,
               lambda t: t.replace("  rag-data: {}\n", ""),
               "rag-data") and ok

    # The pin is the floor; an unpinned engine moves under everyone.
    ok = plant(rows, "unpinned-engine", COMPOSE,
               lambda t: t.replace(
                   "image: milvusdb/milvus@sha256:38a6ba6378c602bfb187f4f34077f384c160edf1cf329aa22d99fb58b81b2497",
                   "image: milvusdb/milvus:v2.6.6"),
               "digest-pinned") and ok

    # The seam half: a route that is drawn nowhere, and a role the entrypoint
    # does not know. The second is how this container failed for real.
    ok = plant(rows, "route-missing", ROUTES,
               lambda t: t.replace('  when "rag"', '  when "rag_disabled"'),
               "ROLE=rag branch") and ok

    ok = plant(rows, "entrypoint-blind", ENTRYPOINT,
               lambda t: t.replace("\n  rag)", "\n  rag_disabled)"),
               "does not know ROLE=rag") and ok

    r = run()
    rows.append(("restored", r.returncode == 0, "exit %d" % r.returncode))
    ok = (r.returncode == 0) and ok

    for name, passed, detail in rows:
        print("  %s %s -- %s" % ("ok" if passed else "FAIL", name, detail))
    print("population: %d examined, 0 skipped" % len(rows))
    print("plant rag: %s" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
