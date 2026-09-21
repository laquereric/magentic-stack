#!/usr/bin/env python3
"""Fail if MIND's prepare copy of NOOA is no longer a plant from the pin.

docs/pydantic-upgrades.md rec 6. prepare's default SRC must be the pin's
submodule_path, and the prepare destination must stay gitignored. The copy
is a build artifact, not a second home.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

PIN = Path("upstreams/manifests/nooa.pin.json")
PREPARE = Path("runtimes/mind-pod/mind/bin/prepare")
GITIGNORE = Path("runtimes/mind-pod/mind/.gitignore")
COMPOSE = Path("runtimes/mind-pod/docker-compose.yml")
DOCKER = Path("runtimes/mind-pod/mind/Dockerfile")


def fail_empty_check_root():
    if "CHECK_ROOT" in os.environ and not str(os.environ.get("CHECK_ROOT", "")).strip():
        print("FAIL: empty CHECK_ROOT", file=sys.stderr)
        return True
    return False


def root_from_env():
    raw = os.environ.get("CHECK_ROOT")
    if raw is None:
        return Path(__file__).resolve().parents[2]
    return Path(raw)


def main() -> int:
    if fail_empty_check_root():
        return 1
    root = root_from_env()
    checks = []

    def check(name, ok, detail=""):
        checks.append((name, bool(ok), str(detail)))
        return bool(ok)

    pin = json.loads((root / PIN).read_text(encoding="utf-8"))
    sub = str(pin.get("submodule_path") or "")
    prepare = (root / PREPARE).read_text(encoding="utf-8")
    gi = (root / GITIGNORE).read_text(encoding="utf-8")
    compose = (root / COMPOSE).read_text(encoding="utf-8") if (root / COMPOSE).is_file() else ""
    df = (root / DOCKER).read_text(encoding="utf-8") if (root / DOCKER).is_file() else ""
    ok = True
    ok = check("submodule-path-set", bool(sub), sub) and ok
    ok = check("prepare-defaults-to-pin", sub in prepare, "prepare contains %s" % sub) and ok
    ignored = any("nooa" in ln and ln.strip().startswith("/") for ln in gi.splitlines())
    ok = check("prepare-dest-gitignored", ignored, "nooa dest ignored") and ok
    # THE PIN IS WHERE THE BYTES COME FROM, WHICH IS NOT THE SAME AS A PATH
    # STRING. This asserted the literal submodule_path appeared in compose. The
    # named context now points at the pin's PARENT and the Dockerfile COPYs
    # `src` from it -- because NOOA's own .dockerignore excludes *.md while its
    # pyproject force-includes THIRD_PARTY_NOTICES.md, and .dockerignore is
    # context-root scoped, so naming the parent is the only way to get the pin's
    # own bytes without forking a FOLLOW-THEM tree.
    #
    # Same pin, different spelling. So the pair is checked TOGETHER and this is
    # stricter than it was: naming the parent is only accepted when the
    # Dockerfile actually copies the pin's leaf out of it, which the old string
    # match never looked at.
    parent, leaf = os.path.split(sub.rstrip("/"))
    direct = sub in compose
    via_parent = (parent in compose) and ("--from=nooa_src %s" % leaf) in df
    ok = check("compose-named-context",
               "nooa_src" in compose and (direct or via_parent),
               "compose takes the pin path" if direct
               else ("compose takes %s and the Dockerfile COPYs %s" % (parent, leaf) if via_parent
                     else "compose names neither the pin nor its parent-with-COPY")) and ok
    ok = check("dockerfile-from-pin", "--from=nooa_src" in df, "Dockerfile COPY --from=nooa_src") and ok
    populated, _pop = emit_population(len(checks))
    if not populated:
        return 1
    print("check | ok | detail")
    print("------|----|--------")
    for name, passed, detail in checks:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    if not ok:
        print("nooa-vendor: FAIL", file=sys.stderr)
        return 1
    print("nooa-vendor: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
