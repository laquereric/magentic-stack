#!/usr/bin/env python3
"""Fail if any pod container can bind a sqlite path outside the closed set,
or bind a member under a role the set does not declare.

Rows 39 (the closed set lives in store_bindings.json) and 43 (persist's
invariant, enforced here before persist exists). Two writers on one file
becomes a compose edit today; this gate makes it a failed sweep instead:
every DB_PATH/BUS_DB_PATH value in both compose files must be an exact
member of the set, every sqlite volume mount must match the declared
writer-set and mode (rw vs :ro), and every declared (store, role) pair
must actually appear in both files.

Writer-SET, not single-writer: back+backjob share the domain file by ADR
0056 declaration. 0051 section 5 still says "no two roles at one path" --
that sentence owes an amendment (ROW8 section 7); this gate enforces the
reframing, not the sentence.

Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import json
import os
import posixpath
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

COMPOSE_FILES = (
    Path("runtimes/mind-pod/docker-compose.yml"),
    Path("runtimes/mind-pod/app/extract/compose.yml"),
)
BINDINGS = Path("runtimes/mind-pod/app/config/store_bindings.json")
WRITERS = Path("runtimes/mind-pod/app/config/domain_writers.json")
ENV_VARS = ("DB_PATH", "BUS_DB_PATH", "PERSIST_DB_PATH")


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


def strip_comments(text: str) -> str:
    return "\n".join(
        line for line in text.splitlines()
        if not line.strip().startswith("#")
    )


def services(text: str):
    """Split compose text into (name, block) for top-level services."""
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


def role_of(name: str, block: str) -> str:
    m = re.search(r"ROLE:\s*[\"']?([A-Za-z0-9_-]+)", block)
    return m.group(1) if m else name


def env_paths(block: str):
    """Yield (var, value) for DB_PATH/BUS_DB_PATH/PERSIST_DB_PATH assignments."""
    for m in re.finditer(r"(PERSIST_DB_PATH|BUS_DB_PATH|DB_PATH)\s*:\s*[\"']?([^\s,\"'}]+)", block):
        yield m.group(1), m.group(2)


def mounts(block: str):
    """Yield (source, target, ro) for quoted volume entries."""
    for m in re.finditer(r'"([A-Za-z0-9_./-]+):(/[A-Za-z0-9_./-]+)(:ro)?"', block):
        yield m.group(1), m.group(2), m.group(3) == ":ro"


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
    try:
        spec = json.loads((root / BINDINGS).read_text(encoding="utf-8"))
        stores = spec.get("stores") or []
    except (OSError, json.JSONDecodeError) as e:
        errors.append("unreadable %s: %s" % (BINDINGS.as_posix(), e))
        stores = []
    by_path = {}
    by_volume = {}
    if stores:
        print("  ok %s (%d stores)" % (BINDINGS.as_posix(), len(stores)))
    for s in stores:
        examined += 1
        for key in ("id", "path", "volume", "env", "rw", "ro"):
            if key not in s:
                errors.append("store %r missing %s" % (s.get("id"), key))
        if s.get("env") not in ENV_VARS:
            errors.append("store %r env %r is not a governed var" % (s.get("id"), s.get("env")))
        if s.get("path") in by_path:
            errors.append("duplicate closed-set path %s" % s.get("path"))
        if s.get("volume") in by_volume:
            errors.append("duplicate closed-set volume %s" % s.get("volume"))
        by_path[s.get("path")] = s
        by_volume[s.get("volume")] = s

    examined += 1
    try:
        writers = json.loads((root / WRITERS).read_text(encoding="utf-8"))
        known_roles = set((writers.get("roles") or {}).keys()) | {"mind"}
    except (OSError, json.JSONDecodeError) as e:
        errors.append("unreadable %s: %s" % (WRITERS.as_posix(), e))
        known_roles = set()
    else:
        print("  ok %s" % WRITERS.as_posix())
    for s in stores:
        for role in list(s.get("rw") or []) + list(s.get("ro") or []):
            examined += 1
            if role not in known_roles:
                errors.append("store %r names unknown role %r" % (s.get("id"), role))

    for rel in COMPOSE_FILES:
        examined += 1
        p = root / rel
        raw = p.read_text(encoding="utf-8", errors="replace") if p.is_file() else ""
        if not p.is_file():
            errors.append("missing %s" % rel.as_posix())
            continue
        text = strip_comments(raw)
        svcs = services(text)
        if not svcs:
            errors.append("%s has no services" % rel.as_posix())
            continue
        print("  ok %s (%d services)" % (rel.as_posix(), len(svcs)))
        seen = set()
        for name, block in svcs:
            role = role_of(name, block)
            for var, value in env_paths(block):
                examined += 1
                hit = [s for s in stores if s.get("path") == value and s.get("env") == var]
                if not hit:
                    errors.append(
                        "%s %s sets %s=%s, not a closed-set member"
                        % (rel.as_posix(), name, var, value)
                    )
                else:
                    seen.add((hit[0].get("id"), role, "env"))
            for source, target, ro in mounts(block):
                if source not in by_volume:
                    continue
                examined += 1
                s = by_volume[source]
                if posixpath.dirname(s.get("path")) != target.rstrip("/"):
                    errors.append(
                        "%s %s mounts %s at %s, want %s"
                        % (rel.as_posix(), name, source, target, posixpath.dirname(s.get("path")))
                    )
                    continue
                mode = "ro" if ro else "rw"
                want = s.get("ro") if ro else s.get("rw")
                if role not in (want or []):
                    errors.append(
                        "%s %s mounts %s %s, declared %s is %s"
                        % (rel.as_posix(), name, source, mode, mode, want)
                    )
                else:
                    seen.add((s.get("id"), role, mode))
        for s in stores:
            for role in s.get("rw") or []:
                examined += 1
                if (s.get("id"), role, "rw") not in seen or (s.get("id"), role, "env") not in seen:
                    errors.append(
                        "%s missing declared %s rw bind (mount+env) for %s"
                        % (rel.as_posix(), s.get("id"), role)
                    )
            for role in s.get("ro") or []:
                examined += 1
                if (s.get("id"), role, "ro") not in seen or (s.get("id"), role, "env") not in seen:
                    errors.append(
                        "%s missing declared %s ro bind (mount+env) for %s"
                        % (rel.as_posix(), s.get("id"), role)
                    )
        for s in stores:
            examined += 1
            if not re.search(r"^\s+%s:\s*(\{\})?\s*$" % re.escape(s.get("volume")), text, re.M):
                errors.append("%s declares no named volume %s" % (rel.as_posix(), s.get("volume")))
            else:
                print("  ok %s declares %s" % (rel.as_posix(), s.get("volume")))
        examined += 1
        tokens = {m.group(1).rstrip(",}\"']") for m in re.finditer(r"(\S+\.sqlite3\S*)", text, re.I)}
        strays = sorted(t for t in tokens if not any(t in s.get("path") for s in stores))
        if strays:
            errors.append("%s has sqlite literals outside the closed set: %s" % (rel.as_posix(), strays))
        else:
            print("  ok %s no stray sqlite paths" % rel.as_posix())

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("STORE BINDINGS FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("store bindings: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
