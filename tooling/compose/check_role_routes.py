#!/usr/bin/env python3
"""Fail when a ROLE draws a route outside its declared surface.

Do not parse routes.rb. Boot the mind-pod app once per discovered ROLE and
read Rails.application.routes.routes. That is the only view that sees a
mount from an initializer, a constant, or any other construct a case-statement
parser would miss.

Roles are DISCOVERED from extract/entrypoint.sh and both hand-kept compose
files, then checked both ways against tooling/compose/role_routes.json:
  - a ROLE that exists and has no expectation -> FAIL undeclared role
  - an expectation for a ROLE that exists nowhere -> FAIL orphan role

The app is copied from CHECK_ROOT so a plant of routes.rb is what Rails
actually draws. Dummy vault env is supplied only so ROLE=vault can finish
boot; it is not a default in compose.

A skipped route is a FAIL (gap 51). The dumper used to drop any path
starting /rails as "rails internal"; a planted GET /rails/backdoor was
printed and the gate still exited 0.

Seven boots (back, front, vault, backjob, config, shape, bus) after the image exists.
No cheaper proxy.
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

COMPOSE_FILES = (
    "runtimes/mind-pod/docker-compose.yml",
    "runtimes/mind-pod/app/extract/compose.yml",
)
ENTRYPOINT = "runtimes/mind-pod/app/extract/entrypoint.sh"
APP_DIR = "runtimes/mind-pod/app"
RECORD = "tooling/compose/role_routes.json"
DUMPER = "tooling/compose/dump_role_routes.rb"

SERVICE_RE = re.compile(r"^  ([A-Za-z0-9_-]+):\s*$")
INLINE_ENV_RE = re.compile(r"^    environment:\s*\{(.+)\}\s*$")
BLOCK_ENV_RE = re.compile(r"^    environment:\s*$")
ROLE_VALUE_RE = re.compile(r"""ROLE:\s*['"]?([A-Za-z0-9_-]+)""")
CASE_ROLE_RE = re.compile(r'^\s*case\s+"\$ROLE"')
CASE_BRANCH_RE = re.compile(r"^\s+([a-z][a-z0-9_-]*)\)\s*$")
ESAC_RE = re.compile(r"^\s*esac\b")

VAULT_DUMP_ENV = {
    "VAULT_CALLERS": json.dumps(
        {
            "config-admin": {"token": "dump-admin", "operations": ["put", "list"]},
            "llm-plane": {"token": "dump-llm", "operations": ["get"]},
        }
    ),
    "VAULT_MASTER_KEY": "dump-master",
    "VAULT_STORE_PATH": "/tmp/role-routes-vault.json",
    "SECRET_KEY_BASE": "dump-secret-key-base-not-the-pod-default",
    # ROLE=config fail-closed boot (gap 5). Dummy values; the dumper
    # never calls vault.
    "VAULT_URL": "http://vault:3000",
    "VAULT_TOKEN": "dump-admin",
    "PERSIST_URL": "http://persist:3000",
    "PERSIST_TOKEN": "dump-persist",
    # ROLE=persist fail-closed boot (row 8). Dummy caller; the dumper
    # never calls persist.
    "PERSIST_CALLERS": json.dumps(
        {
            "config-admin": {"token": "dump-persist", "operations": ["set", "get"]},
        }
    ),
}


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


def compose_roles(path: Path):
    roles = set()
    if not path.is_file():
        return roles
    in_services = False
    in_env_block = False
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("services:"):
            in_services = True
            in_env_block = False
            continue
        if in_services and re.match(r"^[A-Za-z]", line):
            in_services = False
            in_env_block = False
            continue
        if not in_services:
            continue
        if SERVICE_RE.match(line):
            in_env_block = False
            continue
        m = INLINE_ENV_RE.match(line)
        if m:
            in_env_block = False
            rm = ROLE_VALUE_RE.search(m.group(1))
            if rm:
                roles.add(rm.group(1))
            continue
        if BLOCK_ENV_RE.match(line):
            in_env_block = True
            continue
        if in_env_block:
            if re.match(r"^    \S", line):
                in_env_block = False
            else:
                rm = ROLE_VALUE_RE.search(line)
                if rm:
                    roles.add(rm.group(1))
    return roles


def entrypoint_roles(path: Path):
    roles = set()
    if not path.is_file():
        return roles
    in_case = False
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if CASE_ROLE_RE.match(line):
            in_case = True
            continue
        if in_case and ESAC_RE.match(line):
            in_case = False
            continue
        if not in_case:
            continue
        m = CASE_BRANCH_RE.match(line)
        if m:
            roles.add(m.group(1))
    return roles


def discover_roles(root: Path):
    found = set()
    sources = []
    ep = root / ENTRYPOINT
    er = entrypoint_roles(ep)
    found |= er
    sources.append("entrypoint %s (%s)" % (ENTRYPOINT, ",".join(sorted(er)) or "none"))
    for rel in COMPOSE_FILES:
        cr = compose_roles(root / rel)
        found |= cr
        sources.append("compose %s (%s)" % (rel, ",".join(sorted(cr)) or "none"))
    return found, sources


def load_record(root: Path):
    path = root / RECORD
    if not path.is_file():
        return None, "record file missing: %s" % path.as_posix()
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        return None, "record file unparseable: %s" % e
    if not isinstance(data, dict) or not isinstance(data.get("roles"), dict):
        return None, "record file missing roles{}"
    return data, None


def normalize_path(path: str) -> str:
    return path.replace("(.:format)", "")


def route_label(route: dict) -> str:
    verb = route.get("verb") or "MOUNT"
    if verb == "":
        verb = "MOUNT"
    return "%s %s" % (verb, normalize_path(route.get("path") or ""))


def verbs_of(route: dict):
    raw = (route.get("verb") or "").upper()
    if not raw:
        return set()
    return {v for v in raw.split("|") if v}


def rule_covers_route(rule: dict, route: dict) -> bool:
    path = normalize_path(route.get("path") or "")
    if rule.get("mount"):
        mount = str(rule["mount"]).rstrip("/") or "/"
        return path == mount or path.startswith(mount + "/")
    want_m = str(rule.get("method") or "").upper()
    want_p = str(rule.get("path") or "")
    if not want_m or not want_p:
        return False
    if path != want_p:
        return False
    have = verbs_of(route)
    if want_m in have:
        return True
    if want_m == "GET" and "HEAD" in have:
        return True
    return False


def rule_label(rule: dict) -> str:
    if rule.get("mount"):
        return "MOUNT %s" % rule["mount"]
    return "%s %s" % (rule.get("method"), rule.get("path"))


def allowed_rules(record: dict, role: str):
    rules = list(record.get("shared") or [])
    rules.extend(record.get("roles", {}).get(role) or [])
    return rules


def dump_role(boot_app: Path, dumper: Path, role: str, image: str):
    cmd = [
        "docker",
        "run",
        "--rm",
        "--entrypoint",
        "bundle",
        "-v",
        "%s:/rails" % str(boot_app.resolve()),
        "-v",
        "%s:/dump_role_routes.rb:ro" % str(dumper.resolve()),
        "-e",
        "ROLE=%s" % role,
        "-e",
        "RAILS_ENV=production",
    ]
    for k, v in VAULT_DUMP_ENV.items():
        cmd.extend(["-e", "%s=%s" % (k, v)])
    cmd.extend([image, "exec", "rails", "runner", "/dump_role_routes.rb"])
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=90)
    except FileNotFoundError:
        return None, "docker not installed"
    except subprocess.TimeoutExpired:
        return None, "boot timed out for role %s" % role
    if proc.returncode != 0:
        err = (proc.stderr or proc.stdout or "").strip().splitlines()
        interesting = [ln.strip() for ln in err if re.search(r"Invalid|Error|already in use|uninitialized", ln)]
        tail = interesting[:4] if interesting else (err[-4:] if err else ["exit %d" % proc.returncode])
        return None, "boot failed for role %s: %s" % (role, " | ".join(tail))
    raw = (proc.stdout or "").strip().splitlines()
    if not raw:
        return None, "empty dump for role %s" % role
    try:
        data = json.loads(raw[-1])
    except json.JSONDecodeError as e:
        return None, "unparseable dump for role %s: %s" % (role, e)
    if data.get("role") != role:
        return None, "dump role %s != asked %s" % (data.get("role"), role)
    return data, None


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

    discovered, sources = discover_roles(root)
    record, rec_err = load_record(root)
    declared = set((record or {}).get("roles") or {})

    print("  discovery:")
    for s in sources:
        print("    %s" % s)
    print("  discovered roles: %s" % (",".join(sorted(discovered)) or "(none)"))

    errors = []
    if rec_err:
        errors.append(rec_err)

    for role in sorted(discovered - declared):
        errors.append("undeclared role %s (in entrypoint or compose, not in %s)" % (role, RECORD))
    for role in sorted(declared - discovered):
        errors.append("orphan role %s (in %s, not in entrypoint or compose)" % (role, RECORD))

    ok_pop, _ = emit_population(len(discovered), skipped=0)
    if not ok_pop:
        return 1

    missing_files = [p for p in COMPOSE_FILES + (ENTRYPOINT,) if not (root / p).is_file()]
    if missing_files:
        print("FAIL: expected topology file missing", file=sys.stderr)
        for p in missing_files:
            print("  missing %s" % p, file=sys.stderr)
        return 1

    image = os.environ.get("MIND_POD_IMAGE") or "mind-pod:latest"
    print("  image=%s" % image)

    app_src = root / APP_DIR
    dumper = root / DUMPER
    if not app_src.is_dir():
        print("FAIL: app dir missing: %s" % app_src.as_posix(), file=sys.stderr)
        return 1
    if not dumper.is_file():
        print("FAIL: dumper missing: %s" % dumper.as_posix(), file=sys.stderr)
        return 1

    # Copy CHECK_ROOT's app so a plant of routes.rb is what Rails draws, without
    # bundler rewriting the tree's Gemfile.lock.
    boot_tmp = Path(tempfile.mkdtemp(prefix="role-routes-boot-"))
    boot_app = boot_tmp / "app"
    shutil.copytree(app_src, boot_app, ignore=shutil.ignore_patterns("log", "tmp", ".git"))

    to_dump = sorted(discovered & declared) if record else []
    try:
        for role in to_dump:
            data, err = dump_role(boot_app, dumper, role, image)
            if err:
                errors.append(err)
                print("  role %s: DUMP FAIL" % role)
                continue
            routes = data.get("routes") or []
            skipped = data.get("skipped") or []
            print("  role %s: %d routes, %d skipped" % (role, len(routes), len(skipped)))
            for s in skipped:
                # A skip is not a pass. Path-prefix skips were the gap-51 hole:
                # GET /rails/backdoor was printed and the gate still exited 0.
                errors.append("%s skipped %s (skipped is not a pass)" % (role, route_label(s)))
                print("    skipped %s (%s)" % (route_label(s), s.get("reason") or "unspecified"))
            for r in routes:
                print("    drawn %s" % route_label(r))
            rules = allowed_rules(record, role)
            for r in routes:
                if not any(rule_covers_route(rule, r) for rule in rules):
                    errors.append("%s extra %s" % (role, route_label(r)))
            for rule in rules:
                if not any(rule_covers_route(rule, r) for r in routes):
                    errors.append("%s missing %s" % (role, rule_label(rule)))
    finally:
        shutil.rmtree(boot_tmp, ignore_errors=True)

    if errors:
        print("ROLE ROUTES FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1

    print("role routes: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
