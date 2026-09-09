#!/usr/bin/env python3
"""Fail if the in-pod NATS broker is missing, published, unpinned, or unused.

ADR 0065: nats is the 12th container, a third-party L7 broker analogous to
graph. It is not ROLE=bus. In-pod CPCP rides NATS so HTTP inside the pod
can be disabled; the broker itself is never host-published.

Both compose files are a gate of their own. Empty CHECK_ROOT fails.
0 examined is not a pass.
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
SERVICE = "nats"
REQUIRED_ENV = "MM_NATS_URL"
REQUIRED_URL = "nats://nats:4222"
CLIENTS = (
    "back", "backjob", "bus", "persist", "front", "vault",
    "config", "shape", "mind", "switch",
)
IMAGE_RE = re.compile(r"^    image:\s*(.+)$")
BUILD_RE = re.compile(r"^    build:")
PORTS_RE = re.compile(r"^    ports\s*:")
VOL_INLINE = re.compile(r"^    volumes:\s*\[(.+)\]")
CMD_RE = re.compile(r"^    command:\s*\[(.+)\]")
SERVICE_RE = re.compile(r"^  ([A-Za-z0-9_-]+):\s*$")
INLINE_ENV_RE = re.compile(r"^    environment:\s*\{(.+)\}\s*$")
BLOCK_ENV_RE = re.compile(r"^    environment:\s*$")
ENV_KEY_RE = re.compile(r"^      ([A-Za-z_][A-Za-z0-9_]*)\s*:")
INLINE_KEY_RE = re.compile(r"([A-Za-z_][A-Za-z0-9_]*)\s*:")
INLINE_VAL_RE = re.compile(
    r"""MM_NATS_URL:\s*["']([^"']+)["']"""
)
BLOCK_VAL_RE = re.compile(
    r"""^      MM_NATS_URL:\s*["']([^"']+)["']"""
)


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


def parse_env(block: str):
    keys = set()
    url = None
    for line in block.splitlines():
        m = INLINE_ENV_RE.match(line)
        if m:
            blob = m.group(1)
            for km in INLINE_KEY_RE.finditer(blob):
                keys.add(km.group(1))
            vm = INLINE_VAL_RE.search(blob)
            if vm:
                url = vm.group(1)
            continue
        if BLOCK_ENV_RE.match(line):
            continue
        km = ENV_KEY_RE.match(line)
        if km:
            keys.add(km.group(1))
        vm = BLOCK_VAL_RE.match(line)
        if vm:
            url = vm.group(1)
    return keys, url


def nats_meta(block: str):
    image = ""
    build = False
    ports = False
    volumes = ""
    command = ""
    for line in block.splitlines():
        m = IMAGE_RE.match(line)
        if m:
            image = m.group(1).strip().strip('"').strip("'")
        if BUILD_RE.match(line):
            build = True
        if PORTS_RE.match(line):
            ports = True
        m = VOL_INLINE.match(line)
        if m:
            volumes = m.group(1)
        m = CMD_RE.match(line)
        if m:
            command = m.group(1)
    return image, build, ports, volumes, command


def top_volumes(text: str):
    m = re.search(r"^volumes:\s*$", text, re.M)
    if not m:
        return set()
    names = set()
    for line in text[m.end():].splitlines():
        mm = re.match(r"^  ([A-Za-z0-9_-]+):\s*(\{\}|)$", line)
        if mm:
            names.add(mm.group(1))
    return names


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

    for rel in COMPOSE_FILES:
        path = root / rel
        examined += 1
        if not path.is_file():
            errors.append("missing %s" % rel.as_posix())
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        svcs = dict(services(text))
        print("  compose %s services=%d nats=%s" % (
            rel.as_posix(), len(svcs), SERVICE in svcs))
        if SERVICE not in svcs:
            errors.append("%s has no %s service" % (rel.as_posix(), SERVICE))
            continue
        image, build, ports, volumes, command = nats_meta(svcs[SERVICE])
        print("    nats image=%s build=%s ports=%s" % (image[:70], build, ports))
        if "@sha256:" not in image:
            errors.append("%s nats image is not digest-pinned: %s" % (rel.as_posix(), image))
        repo = image.split("@", 1)[0].split(":", 1)[0].rsplit("/", 1)[-1].lower()
        if repo != "nats":
            errors.append("%s nats image is not official nats: %s" % (rel.as_posix(), image))
        if build:
            errors.append("%s nats has a build context (we ship source)" % rel.as_posix())
        if ports:
            errors.append("%s nats is host-published (in-pod broker must be unpublished)" % rel.as_posix())
        if "nats-data" not in volumes:
            errors.append("%s nats does not mount nats-data" % rel.as_posix())
        if "-js" not in command:
            errors.append("%s nats command missing -js (JetStream)" % rel.as_posix())
        if "-sd" not in command:
            errors.append("%s nats command missing -sd (store dir)" % rel.as_posix())
        if "nats-data" not in top_volumes(text):
            errors.append("%s top-level volumes missing nats-data" % rel.as_posix())

        for name in CLIENTS:
            if name not in svcs:
                errors.append("%s missing client service %s" % (rel.as_posix(), name))
                continue
            keys, url = parse_env(svcs[name])
            if REQUIRED_ENV not in keys:
                errors.append(
                    "%s service=%s missing %s (in-pod CPCP rides NATS)"
                    % (rel.as_posix(), name, REQUIRED_ENV)
                )
            elif url != REQUIRED_URL:
                errors.append(
                    "%s service=%s %s=%s want %s"
                    % (rel.as_posix(), name, REQUIRED_ENV, url, REQUIRED_URL)
                )
            else:
                print("    ok %s has %s" % (name, REQUIRED_ENV))

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if examined == 0:
        print("FAIL: empty compose population", file=sys.stderr)
        return 1
    if errors:
        print("NATS FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("nats: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
