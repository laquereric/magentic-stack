#!/usr/bin/env python3
"""Fail if a domain-writer ROLE in a compose file that defines graph
has no MM_OXIGRAPH_URL.

Gap 7 mechanical half. ADR 0056 writers are back and backjob. Execute
defaults to localhost:7878, which inside those containers is not GRAPH.

Any compose file (not a hardcoded pair) is a gate of its own. A service
is a writer only when it sets ROLE to back or backjob. Overlays that
repeat the service name without ROLE are not writers. Empty CHECK_ROOT
fails. 0 examined is not a pass.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

WRITER_ROLES = frozenset({"back", "backjob"})
GRAPH_SERVICE = "graph"
REQUIRED = "MM_OXIGRAPH_URL"
SKIP_DIR_NAMES = frozenset({".git", "vendor", "node_modules", ".bundle", "__pycache__"})
COMPOSE_EXACT = frozenset({"compose.yml", "compose.yaml", "docker-compose.yml", "docker-compose.yaml"})

SERVICE_RE = re.compile(r"^  ([A-Za-z0-9_-]+):\s*$")
INLINE_ENV_RE = re.compile(r"^    environment:\s*\{(.+)\}\s*$")
BLOCK_ENV_RE = re.compile(r"^    environment:\s*$")
ENV_KEY_RE = re.compile(r"^      ([A-Za-z_][A-Za-z0-9_]*)\s*:")
INLINE_KEY_RE = re.compile(r"([A-Za-z_][A-Za-z0-9_]*)\s*:")
ROLE_VALUE_RE = re.compile(r"""ROLE:\s*['"]?([A-Za-z0-9_-]+)""")


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


def is_compose_name(name: str) -> bool:
    if name in COMPOSE_EXACT:
        return True
    if name.startswith("docker-compose") and name.endswith((".yml", ".yaml")):
        return True
    return False


def compose_files(root: Path):
    out = []
    for p in root.rglob("*"):
        if not p.is_file():
            continue
        rel_parts = p.relative_to(root).parts
        if any(part in SKIP_DIR_NAMES for part in rel_parts):
            continue
        if is_compose_name(p.name):
            out.append(p)
    return sorted(out)


def parse_compose_services(path: Path):
    """Service name -> env keys, plus ROLE value if present."""
    services = {}
    roles = {}
    current = None
    in_services = False
    in_env_block = False
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("services:"):
            in_services = True
            current = None
            in_env_block = False
            continue
        if in_services and re.match(r"^[A-Za-z]", line):
            in_services = False
            current = None
            in_env_block = False
            continue
        if not in_services:
            continue
        m = SERVICE_RE.match(line)
        if m:
            current = m.group(1)
            services.setdefault(current, set())
            in_env_block = False
            continue
        if current is None:
            continue
        m = INLINE_ENV_RE.match(line)
        if m:
            in_env_block = False
            blob = m.group(1)
            for km in INLINE_KEY_RE.finditer(blob):
                services[current].add(km.group(1))
            rm = ROLE_VALUE_RE.search(blob)
            if rm:
                roles[current] = rm.group(1)
            continue
        if BLOCK_ENV_RE.match(line):
            in_env_block = True
            continue
        if in_env_block:
            if re.match(r"^    \S", line):
                in_env_block = False
            else:
                km = ENV_KEY_RE.match(line)
                if km:
                    services[current].add(km.group(1))
                rm = ROLE_VALUE_RE.search(line)
                if rm:
                    roles[current] = rm.group(1)
    return services, roles


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

    files = compose_files(root)
    errors = []
    examined = 0
    requirements = 0

    for path in files:
        examined += 1
        try:
            rel = path.relative_to(root).as_posix()
        except ValueError:
            rel = str(path)
        services, roles = parse_compose_services(path)
        has_graph = GRAPH_SERVICE in services
        print("  compose %s services=%d graph=%s" % (rel, len(services), has_graph))
        if not has_graph:
            continue
        writers = [(name, roles[name]) for name in services if roles.get(name) in WRITER_ROLES]
        if not writers:
            print("    graph present, no ROLE=back/backjob in this file")
            continue
        for name, role in writers:
            requirements += 1
            keys = services.get(name) or set()
            if REQUIRED in keys:
                print("    ok %s ROLE=%s has %s" % (name, role, REQUIRED))
            else:
                errors.append(
                    "%s service=%s ROLE=%s missing %s (file defines graph)"
                    % (rel, name, role, REQUIRED)
                )

    ok_pop, _ = emit_population(examined, skipped=0)
    print("  compose-files=%d writer-graph-requirements=%d" % (len(files), requirements))
    if not ok_pop:
        return 1
    if errors:
        print("OXIGRAPH ENV FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("oxigraph env: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
