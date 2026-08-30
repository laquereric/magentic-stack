#!/usr/bin/env python3
"""Fail when a role reads ENV.fetch(VAR, loopback-default) and compose omits VAR.

A loopback default is the local container, not the peer service. BACKJOB
reading BACK_URL with a 127.0.0.1 fallback never reaches BACK; the
never-raise rescue then prints ok=false and no l8.execution.complete lands.

Scan: runtimes/mind-pod/**/*.rb and ruby shebang scripts under bin/
(role code). Specs and tests are skipped. bin/backjob has no .rb suffix.
Compose files (hand-kept, not generated):
  runtimes/mind-pod/docker-compose.yml
  runtimes/mind-pod/app/extract/compose.yml
Each file is a gate of its own.

A fetch in bin/<service> binds to that service. A fetch in shared app
code binds to every compose service that sets ROLE to back, front, or
backjob (the one image, three roles).

Empty CHECK_ROOT fails closed. Zero compose files or zero ruby files
is not a pass.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

COMPOSE_FILES = (
    "runtimes/mind-pod/docker-compose.yml",
    "runtimes/mind-pod/app/extract/compose.yml",
)
SCAN_ROOT = "runtimes/mind-pod"
RAILS_ROLES = frozenset({"back", "front", "backjob"})
SKIP_DIR_NAMES = frozenset({"spec", "test", "vendor", ".git"})

FETCH_RE = re.compile(
    r"""ENV\.fetch\(\s*['"]([A-Z][A-Z0-9_]*)['"]\s*,\s*['"]([^'"]*)['"]""",
)
LOOPBACK_RE = re.compile(
    r"(?i)(?:^|[^\w.])(?:localhost|127\.0\.0\.1|\[::1\]|::1)(?:[^\w.]|$)",
)
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


def parse_compose_services(path: Path):
    """Service name -> set of environment keys, plus ROLE value if present."""
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


def is_ruby(path: Path) -> bool:
    if path.suffix == ".rb":
        return True
    if path.parent.name != "bin" or not path.is_file():
        return False
    try:
        first = path.read_text(encoding="utf-8", errors="replace").splitlines()[:1]
    except OSError:
        return False
    return bool(first) and "ruby" in first[0].lower()


def ruby_files(root: Path):
    base = root / SCAN_ROOT
    if not base.is_dir():
        return []
    out = []
    for p in base.rglob("*"):
        if not p.is_file():
            continue
        if any(part in SKIP_DIR_NAMES for part in p.parts):
            continue
        if is_ruby(p):
            out.append(p)
    return sorted(out)


def fetches_in(path: Path):
    rows = []
    for i, raw in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        code = raw.split("#", 1)[0]
        for m in FETCH_RE.finditer(code):
            var, default = m.group(1), m.group(2)
            if LOOPBACK_RE.search(default):
                rows.append((i, var, default))
    return rows


def bind_services(rel: str, service_names, roles):
    path = Path(rel)
    if path.parent.name == "bin" and path.stem in service_names:
        return [path.stem]
    bound = []
    for name, role in roles.items():
        if role in RAILS_ROLES:
            bound.append(name)
    return bound


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

    compose_paths = [root / rel for rel in COMPOSE_FILES]
    present = [p for p in compose_paths if p.is_file()]
    missing = [p for p in compose_paths if not p.is_file()]
    rubies = ruby_files(root)

    ok_pop, _ = emit_population(len(rubies), skipped=0)
    print("  compose files: %d" % len(present))
    print("  scan=%s ruby (*.rb + bin shebang)" % SCAN_ROOT)
    if not ok_pop:
        return 1
    if missing:
        print("FAIL: expected compose file missing", file=sys.stderr)
        for p in missing:
            try:
                print("  missing %s" % p.relative_to(root).as_posix(), file=sys.stderr)
            except ValueError:
                print("  missing %s" % p, file=sys.stderr)
        return 1

    errors = []
    fetch_sites = 0
    requirements = 0

    for rb in rubies:
        rel = rb.relative_to(root).as_posix()
        rows = fetches_in(rb)
        if not rows:
            continue
        for lineno, var, default in rows:
            fetch_sites += 1
            print("  fetch %s:%d ENV.fetch(%s, %s)" % (rel, lineno, var, default))
            for compose in present:
                crel = compose.relative_to(root).as_posix()
                services, roles = parse_compose_services(compose)
                bound = bind_services(rel, services, roles)
                if not bound:
                    errors.append(
                        "%s:%d ENV.fetch(%s) has no compose service in %s"
                        % (rel, lineno, var, crel)
                    )
                    continue
                for svc in bound:
                    requirements += 1
                    keys = services.get(svc) or set()
                    if var in keys:
                        print("    ok %s service=%s var=%s" % (crel, svc, var))
                    else:
                        errors.append(
                            "%s service=%s missing %s (from %s:%d ENV.fetch loopback default %s)"
                            % (crel, svc, var, rel, lineno, default)
                        )

    print("  fetch-sites=%d requirements=%d" % (fetch_sites, requirements))

    if errors:
        print("LOOPBACK ENV FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1

    print("loopback env: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
