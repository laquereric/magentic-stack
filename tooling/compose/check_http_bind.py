#!/usr/bin/env python3
"""Fail if in-pod CPCP HTTP is reachable on the docker network.

ADR 0065: in-pod CPCP is NATS. HTTP on those roles binds 127.0.0.1 and
is not exposed. Host-published operator HTTP (config, extract front,
extract back) binds 0.0.0.0 so the published port works. The entrypoint
default is 127.0.0.1; 0.0.0.0 is opt-in.

Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

COMPOSE_FILES = (
    Path("runtimes/mind-pod/docker-compose.yml"),
    Path("runtimes/mind-pod/app/extract/compose.yml"),
)
ENTRYPOINT = Path("runtimes/mind-pod/app/extract/entrypoint.sh")
RAILS_HTTP = frozenset({"back", "front", "vault", "config", "shape", "bus", "persist"})
INLINE_ENV_RE = re.compile(r"^    environment:\s*\{(.+)\}\s*$")
BLOCK_ENV_RE = re.compile(r"^    environment:\s*$")
ENV_KEY_RE = re.compile(r"^      ([A-Za-z_][A-Za-z0-9_]*)\s*:")
INLINE_KEY_RE = re.compile(r"([A-Za-z_][A-Za-z0-9_]*)\s*:")
HTTP_BIND_INLINE = re.compile(r"""HTTP_BIND:\s*["']([^"']+)["']""")
HTTP_BIND_BLOCK = re.compile(r"""^      HTTP_BIND:\s*["']([^"']+)["']""")
PORTS_RE = re.compile(r"^    ports\s*:")
EXPOSE_RE = re.compile(r"^    expose:\s*\[(.+)\]")


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


def services(text: str):
    m = re.search(r"^services:\s*$", text, re.M)
    if not m:
        return []
    body = text[m.end():]
    names = [(mm.start(), mm.group(1)) for mm in re.finditer(r"^  ([A-Za-z0-9_-]+):\s*$", body, re.M)]
    vols = re.search(r"^[A-Za-z]", body, re.M)
    end = vols.start() if vols else len(body)
    out = []
    for i, (start, name) in enumerate(names):
        stop = names[i + 1][0] if i + 1 < len(names) else end
        out.append((name, body[start:stop]))
    return out


def parse_block(block: str):
    keys = set()
    bind = None
    ports = False
    expose = ""
    for line in block.splitlines():
        m = INLINE_ENV_RE.match(line)
        if m:
            blob = m.group(1)
            for km in INLINE_KEY_RE.finditer(blob):
                keys.add(km.group(1))
            vm = HTTP_BIND_INLINE.search(blob)
            if vm:
                bind = vm.group(1)
            continue
        km = ENV_KEY_RE.match(line)
        if km:
            keys.add(km.group(1))
        vm = HTTP_BIND_BLOCK.match(line)
        if vm:
            bind = vm.group(1)
        if PORTS_RE.match(line):
            ports = True
        m = EXPOSE_RE.match(line)
        if m:
            expose = m.group(1)
    return keys, bind, ports, expose


def main():
    if fail_empty_check_root():
        return 1
    root = root_from_env()
    if not root.is_dir():
        print("FAIL: CHECK_ROOT is not a directory: %s" % root, file=sys.stderr)
        return 1
    try:
        nonempty = any(root.iterdir())
    except OSError as e:
        print("FAIL: CHECK_ROOT unreadable: %s" % e, file=sys.stderr)
        return 1
    if not nonempty:
        print("FAIL: empty CHECK_ROOT tree", file=sys.stderr)
        return 1

    errors = []
    examined = 0

    examined += 1
    ep = root / ENTRYPOINT
    if not ep.is_file():
        errors.append("missing %s" % ENTRYPOINT.as_posix())
    else:
        text = ep.read_text(encoding="utf-8", errors="replace")
        if "HTTP_BIND:-127.0.0.1" not in text and 'HTTP_BIND:-"127.0.0.1"' not in text:
            # ${HTTP_BIND:-127.0.0.1}
            if "${HTTP_BIND:-127.0.0.1}" not in text:
                errors.append("entrypoint default HTTP_BIND is not 127.0.0.1")
        if re.search(r"rails server -b 0\.0\.0\.0", text):
            errors.append("entrypoint hardcodes -b 0.0.0.0 (must use HTTP_BIND)")
        else:
            print("  ok entrypoint default loopback")

    for rel in COMPOSE_FILES:
        path = root / rel
        examined += 1
        if not path.is_file():
            errors.append("missing %s" % rel.as_posix())
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for name, block in services(text):
            if name not in RAILS_HTTP:
                continue
            examined += 1
            keys, bind, ports, expose = parse_block(block)
            print("  %s %s ports=%s bind=%s expose=%s" % (
                rel.as_posix(), name, ports, bind, expose.strip()[:20]))
            if "HTTP_BIND" not in keys or not bind:
                errors.append("%s %s missing HTTP_BIND" % (rel.as_posix(), name))
                continue
            if ports:
                if bind != "0.0.0.0":
                    errors.append(
                        "%s %s is host-published but HTTP_BIND=%s (want 0.0.0.0)"
                        % (rel.as_posix(), name, bind)
                    )
            else:
                if bind != "127.0.0.1":
                    errors.append(
                        "%s %s is in-pod but HTTP_BIND=%s (want 127.0.0.1)"
                        % (rel.as_posix(), name, bind)
                    )
                if "3000" in expose:
                    errors.append(
                        "%s %s exposes 3000 on the docker network (in-pod CPCP is NATS)"
                        % (rel.as_posix(), name)
                    )

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if examined == 0:
        print("FAIL: empty population", file=sys.stderr)
        return 1
    if errors:
        print("HTTP BIND FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("http bind: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
