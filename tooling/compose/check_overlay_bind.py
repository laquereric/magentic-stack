#!/usr/bin/env python3
"""Fail if a test overlay host-publishes a rails role it leaves on loopback.

check_http_bind.py already holds the rule -- host-published HTTP binds 0.0.0.0,
in-pod HTTP binds 127.0.0.1 -- but it reads only docker-compose.yml and
app/extract/compose.yml. The OVERLAYS are where ports are actually published for
CI, and nothing read them.

That blind spot cost gate-session-cycle its entire history. test/
docker-compose.session.yml published 3000:3000 and inherited BACK's
HTTP_BIND=127.0.0.1 from the base, so Puma listened on the CONTAINER's loopback
and the port mapping had nothing to forward to. BACK booted perfectly every
time; the readiness curl burned all 90 attempts; Parts A and B are
continue-on-error and so reported "skipped". The gate failed for 30+ runs
without once evaluating an assertion. Its sibling test/docker-compose.ci.yml
carried the right line all along, which is why gate-boundary-conformance worked.

PUBLISHING A PORT IS NOT BINDING AN INTERFACE, and the difference is invisible
in the overlay alone -- you have to know what the base pinned. So this resolves
the EFFECTIVE value the way compose does: the overlay's HTTP_BIND if it sets
one, otherwise the base's. Requiring the literal line in the overlay would be
wrong for a base that already binds 0.0.0.0.

Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population
from compose.check_http_bind import RAILS_HTTP, parse_block, services

BASE = Path("runtimes/mind-pod/docker-compose.yml")
OVERLAY_DIR = Path("runtimes/mind-pod/test")
OVERLAY_GLOB = "docker-compose.*.yml"


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


def binds_of(path: Path):
    """name -> HTTP_BIND declared in this file (None when the file omits it)."""
    if not path.is_file():
        return None
    text = path.read_text(encoding="utf-8", errors="replace")
    out = {}
    for name, block in services(text):
        _keys, bind, ports, _expose = parse_block(block)
        out[name] = (bind, ports)
    return out


def main() -> int:
    if fail_empty_check_root():
        return 1
    root = root_from_env()
    if not root.is_dir():
        print("FAIL: CHECK_ROOT is not a directory: %s" % root, file=sys.stderr)
        return 1

    base = binds_of(root / BASE)
    if base is None:
        print("FAIL: missing %s" % BASE.as_posix(), file=sys.stderr)
        return 1

    overlays = sorted((root / OVERLAY_DIR).glob(OVERLAY_GLOB)) if (root / OVERLAY_DIR).is_dir() else []
    if not overlays:
        print("FAIL: no overlays found under %s" % OVERLAY_DIR.as_posix(), file=sys.stderr)
        return 1

    errors = []
    examined = 0
    for path in overlays:
        rel = path.relative_to(root).as_posix()
        over = binds_of(path) or {}
        for name, (bind, ports) in sorted(over.items()):
            if name not in RAILS_HTTP:
                continue
            if not ports:
                # The overlay does not publish this role; the base's rule governs
                # it and check_http_bind.py is what holds that.
                continue
            examined += 1
            base_bind = (base.get(name) or (None, False))[0]
            effective = bind or base_bind
            src = "overlay" if bind else "base"
            print("  %s %s ports=True bind=%s (from %s)" % (rel, name, effective, src))
            if effective != "0.0.0.0":
                errors.append(
                    "%s %s publishes a port but effective HTTP_BIND=%s (want 0.0.0.0); "
                    "a published port cannot reach the container's loopback"
                    % (rel, name, effective)
                )

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if examined == 0:
        print("FAIL: empty population (no overlay publishes a rails role)", file=sys.stderr)
        return 1
    if errors:
        print("OVERLAY BIND FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("overlay bind: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
