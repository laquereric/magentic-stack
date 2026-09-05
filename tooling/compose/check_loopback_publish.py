#!/usr/bin/env python3
"""A published port names 127.0.0.1, or it is on the open internet.

spec/scopes.md defines pod_external_cpcp as "reachable from the host, never from
the open internet". Docker decides that, not the doctrine: `ports: ["13003:3000"]`
with no host interface binds 0.0.0.0, and the surface is reachable from wherever
the host is.

Found 2026-09-05 by following the format's rule 4 -- measure exposure, do not
assert it. Four published ports across two compose files all bound 0.0.0.0 while
both scope manifests said "host loopback, never the open internet". Nothing was
wrong with the sentence; it just was not what the files did.

So the sentence is now a check. Every published port in a compose file must name
an explicit loopback host, or say why not.

  ports: [ "127.0.0.1:13003:3000" ]   ok
  ports: [ "13003:3000" ]             fails -- binds 0.0.0.0
  ports: [ "0.0.0.0:13003:3000" ]     fails -- says the quiet part out loud

An internet-facing service is a real thing and this does not forbid it: list it
in PUBLIC_ON_PURPOSE below, with a reason. What is forbidden is publishing to
the world by leaving the address out.

Reads YAML without pyyaml -- the ports lines are simple and a checker that needs
a dependency is a checker that gets skipped. Empty CHECK_ROOT fails.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

# A token is a quoted string or a bare run without separators. Quoting matters:
# "[::1]:13003:3000" only survives as one token because it is quoted, and an
# IPv6 host has to arrive whole or the loopback test reads the wrong prefix.
TOKEN = re.compile(r"\"[^\"]*\"|'[^']*'|[^\s,\[\]]+")
# A port MAPPING ends in host:container. "3000" alone is a container port.
MAPPING = re.compile(r"\d+:\d+(?:/\w+)?\Z")
PORTS_KEY = re.compile(r"^(\s*)ports\s*:\s*(.*)$")
LIST_ITEM = re.compile(r"^(\s*)-\s*(.+)$")
LOOPBACK = ("127.0.0.1:", "localhost:", "[::1]:")
COMPOSE_NAMES = ("docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml")
SKIP_DIRS = {".git", "node_modules", ".venv", "venv", "vendor", "dist", "tmp", ".bundle"}

# Services that are SUPPOSED to face the world, each with a reason. Empty today:
# nothing in this repo is internet-facing. The application repo publishes the
# board, and it does that from its own deploy, not from here.
PUBLIC_ON_PURPOSE = {}


def fail_empty_check_root():
    if "CHECK_ROOT" in os.environ and not str(os.environ.get("CHECK_ROOT", "")).strip():
        print("FAIL: empty CHECK_ROOT", file=sys.stderr)
        return True
    return False


def root_from_env():
    raw = os.environ.get("CHECK_ROOT")
    return Path(raw) if raw is not None else Path(__file__).resolve().parents[2]


def entries(value):
    for tok in TOKEN.findall(value):
        tok = tok.strip("\"'")
        if MAPPING.search(tok):
            yield tok


def published_ports(text):
    """Yield (line_number, entry) for every host-published port mapping.

    BOTH YAML FORMS. The inline list and the block list mean the same thing, and
    an earlier version of this only read the inline one -- so
    `ports:` followed by `- "13003:3000"` passed a checker written to forbid
    exactly that. A plant caught it; nothing else would have.
    """
    lines = text.splitlines()
    for n, line in enumerate(lines, 1):
        code = line.split("#", 1)[0]
        m = PORTS_KEY.match(code)
        if not m:
            continue

        indent, inline = m.group(1), m.group(2).strip()
        if inline:
            for entry in entries(inline):
                yield n, entry
            continue

        # Block form: the items follow, indented past the key.
        for j in range(n, len(lines)):
            item_code = lines[j].split("#", 1)[0]
            if not item_code.strip():
                continue
            im = LIST_ITEM.match(item_code)
            if not im or len(im.group(1)) <= len(indent):
                break
            for entry in entries(im.group(2)):
                yield j + 1, entry


def main():
    if fail_empty_check_root():
        return 1
    root = root_from_env()
    if not root.is_dir():
        print("FAIL: CHECK_ROOT is not a directory: %s" % root, file=sys.stderr)
        return 1

    files = []
    for p in root.rglob("*"):
        if not p.is_file() or p.name not in COMPOSE_NAMES:
            continue
        if any(part in SKIP_DIRS for part in p.relative_to(root).parts):
            continue
        files.append(p)

    ok_pop, _ = emit_population(len(files))
    if not ok_pop:
        return 1

    errors = []
    checked = 0
    for p in sorted(files):
        rel = p.relative_to(root).as_posix()
        text = p.read_text(encoding="utf-8", errors="replace")
        for line_no, entry in published_ports(text):
            checked += 1
            if entry.startswith(LOOPBACK):
                continue
            if PUBLIC_ON_PURPOSE.get("%s:%s" % (rel, entry)):
                continue
            errors.append(
                "%s:%d publishes %r without a loopback host, so Docker binds "
                "0.0.0.0 and it is reachable from wherever the host is. Write "
                "127.0.0.1:%s, or declare it in PUBLIC_ON_PURPOSE with a reason."
                % (rel, line_no, entry, entry)
            )

    if errors:
        print("LOOPBACK PUBLISH FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1

    print("loopback publish: OK (%d published port(s) across %d compose file(s))"
          % (checked, len(files)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
