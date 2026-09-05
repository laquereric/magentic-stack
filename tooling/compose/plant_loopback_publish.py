#!/usr/bin/env python3
"""Plants for check_loopback_publish.

The first plant is the defect this repo actually shipped: `ports: ["13003:3000"]`
with no host interface, which Docker binds to 0.0.0.0 while both scope manifests
said "host loopback, never the open internet".

Builds compose files in a temporary tree; touches nothing real.
"""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import textwrap

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CHECKER = os.path.join(ROOT, "tooling/compose/check_loopback_publish.py")


def build(ports_line):
    d = tempfile.mkdtemp(prefix="plant-loopback-")
    with open(os.path.join(d, "docker-compose.yml"), "w", encoding="utf-8") as fh:
        fh.write(textwrap.dedent("""\
            services:
              config:
                image: example
            %s
        """) % ports_line)
    return d


def run(root):
    env = dict(os.environ, CHECK_ROOT=root)
    out = subprocess.run([sys.executable, CHECKER], capture_output=True, text=True, env=env)
    return out.returncode, out.stdout + out.stderr


CASES = [
    ("loopback-passes", '    ports: [ "127.0.0.1:13003:3000" ]', True, None),

    # THE SHIPPED DEFECT. No host interface means 0.0.0.0.
    ("bare-host-port-fails", '    ports: [ "13003:3000" ]', False, "without a loopback host"),

    # Saying it explicitly is no better than saying it by omission.
    ("explicit-any-address-fails", '    ports: [ "0.0.0.0:13003:3000" ]', False,
     "without a loopback host"),

    # A LAN address is not the open internet and is not loopback either.
    ("lan-address-fails", '    ports: [ "192.168.1.10:13003:3000" ]', False,
     "without a loopback host"),

    ("ipv6-loopback-passes", '    ports: [ "[::1]:13003:3000" ]', True, None),

    # Long form, one entry per line.
    ("list-form-bare-fails", '    ports:\n      - "13003:3000"', False,
     "without a loopback host"),

    ("list-form-loopback-passes", '    ports:\n      - "127.0.0.1:13003:3000"', True, None),

    # A container-only port is not published and must not be flagged.
    ("expose-only-passes", '    expose: [ "3000" ]', True, None),

    # A commented-out publication is not a publication.
    ("commented-out-passes", '    # ports: [ "13003:3000" ]', True, None),
]


def main():
    rows = []
    ok = True

    rc, out = run(os.environ.get("PLANT_EMPTY", ""))
    rows.append(("empty-root", rc != 0, "exit %d" % rc))
    ok = ok and rc != 0

    for name, ports_line, should_pass, needle in CASES:
        d = build(ports_line)
        rc, out = run(d)
        if should_pass:
            passed = rc == 0
        else:
            passed = rc != 0 and (needle in out)
        rows.append((name, passed, "exit %d" % rc))
        ok = ok and passed

    for name, passed, detail in rows:
        print("  %-30s %-4s %s" % (name, "ok" if passed else "FAIL", detail))
    print("loopback-publish plants: %s (%d)" % ("OK" if ok else "FAIL", len(rows)))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
