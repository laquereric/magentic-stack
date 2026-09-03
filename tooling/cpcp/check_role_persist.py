#!/usr/bin/env python3
"""Fail if ROLE=persist draws the domain catalog, prepares another DB,
mounts a domain store, or still says RES.

Row 8. Own POST /_cpcp/rpc. No engine. The ledger lives on persist-data,
never mind-data. BACK must not dial persist (row 72 pattern). Callers
allowlisted; empty PERSIST_CALLERS fails closed at boot. Empty CHECK_ROOT
fails. 0 examined is not a pass.
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

ENTRYPOINT = Path("runtimes/mind-pod/app/extract/entrypoint.sh")
COMPOSE_FILES = (
    Path("runtimes/mind-pod/docker-compose.yml"),
    Path("runtimes/mind-pod/app/extract/compose.yml"),
)
ROUTES = Path("runtimes/mind-pod/app/config/routes.rb")
RECORD = Path("tooling/compose/role_routes.json")
SEAMS = Path("tooling/cpcp/seam_authority.json")
WRITERS = Path("runtimes/mind-pod/app/config/domain_writers.json")
CONTROLLER = Path("runtimes/mind-pod/app/app/controllers/persist_cpcp_controller.rb")
BACK_CLIENTS = (
    Path("runtimes/mind-pod/app/app/services/back_cpcp_client.rb"),
    Path("runtimes/mind-pod/app/app/controllers/home_controller.rb"),
    Path("runtimes/mind-pod/app/bin/backjob"),
    Path("runtimes/mind-pod/app/config/initializers/rails_cpcp.rb"),
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


def code_only(text: str) -> str:
    return "\n".join(line.split("#", 1)[0] for line in text.splitlines())


def role_case(text: str, role: str) -> str:
    token = 'when "%s"' % role
    if token not in text:
        return ""
    rest = text.split(token, 1)[1]
    nxt = re.search(r'\n  when "', rest)
    if nxt:
        rest = rest[:nxt.start()]
    end = re.search(r"\n  end\b", rest)
    if end:
        rest = rest[:end.start()]
    return rest


def entrypoint_branch(text: str, role: str) -> str:
    m = re.search(r"^\s+%s\)\s*$" % re.escape(role), text, re.M)
    if not m:
        return ""
    rest = text[m.end():]
    nxt = re.search(r"^\s+[a-z][a-z0-9_-]*\)\s*$", rest, re.M)
    esac = re.search(r"^\s+esac\b", rest, re.M)
    cuts = [i.start() for i in (nxt, esac) if i]
    return rest[: min(cuts)] if cuts else rest


def compose_service(text: str, name: str) -> str:
    m = re.search(r"^  %s:\s*$" % re.escape(name), text, re.M)
    if not m:
        return ""
    rest = text[m.end():]
    nxt = re.search(r"^  [A-Za-z0-9_-]+:\s*$", rest, re.M)
    top = re.search(r"^[A-Za-z]", rest, re.M)
    cuts = [i.start() for i in (nxt, top) if i]
    return rest[: min(cuts)] if cuts else rest


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
    ep = (root / ENTRYPOINT).read_text(encoding="utf-8", errors="replace") if (root / ENTRYPOINT).is_file() else ""
    branch = entrypoint_branch(ep, "persist")
    if not branch:
        errors.append("entrypoint has no persist) branch")
    else:
        if "db:prepare" in branch or "db:seed" in branch:
            errors.append("ROLE=persist entrypoint must not prepare/seed another DB (it owns only the persist DB)")
        if "db:migrate:persist" not in branch:
            errors.append("ROLE=persist entrypoint must migrate its own DB (db:migrate:persist)")
        else:
            print("  ok entrypoint persist) migrates only the persist DB")
        if "PERSIST_CALLERS:?" not in branch:
            errors.append("ROLE=persist entrypoint must fail closed on empty PERSIST_CALLERS")
        else:
            print("  ok entrypoint persist) fail-closed on callers")

    for rel in COMPOSE_FILES:
        examined += 1
        p = root / rel
        text = p.read_text(encoding="utf-8", errors="replace") if p.is_file() else ""
        if not p.is_file():
            errors.append("missing %s" % rel.as_posix())
            continue
        svc = compose_service(text, "persist")
        if not svc:
            errors.append("%s has no persist service" % rel.as_posix())
            continue
        if not re.search(r"ROLE:\s*persist\b", svc):
            errors.append("%s persist service does not set ROLE: persist" % rel.as_posix())
        if re.search(r"^\s+ports:", svc, re.M):
            errors.append("%s persist service is host-published" % rel.as_posix())
        else:
            print("  ok %s persist unpublished" % rel.as_posix())
        if "PERSIST_DB_PATH:" not in svc:
            errors.append("%s persist service does not set PERSIST_DB_PATH (own sqlite)" % rel.as_posix())
        else:
            print("  ok %s persist sets PERSIST_DB_PATH" % rel.as_posix())
        if "persist-data:/" not in svc:
            errors.append("%s persist service does not mount persist-data" % rel.as_posix())
        else:
            print("  ok %s persist mounts persist-data" % rel.as_posix())
        if "mind-data" in svc:
            errors.append("%s persist mounts the domain store (ledger cannot live in the file it places)" % rel.as_posix())
        else:
            print("  ok %s persist mounts no domain store" % rel.as_posix())

    examined += 1
    routes = (root / ROUTES).read_text(encoding="utf-8", errors="replace") if (root / ROUTES).is_file() else ""
    persist_case = role_case(routes, "persist")
    if not persist_case:
        errors.append('routes.rb has no when "persist"')
    else:
        code = code_only(persist_case)
        if "RailsCpcp::Engine" in code:
            errors.append("ROLE=persist mounts RailsCpcp::Engine")
        if "note.create" in code:
            errors.append("ROLE=persist draws note.create")
        if 'post "/_cpcp/rpc"' not in persist_case:
            errors.append("ROLE=persist missing POST /_cpcp/rpc")
        print("  ok routes.rb persist is POST rpc, no engine")

    examined += 1
    rec = json.loads((root / RECORD).read_text(encoding="utf-8")) if (root / RECORD).is_file() else {}
    rules = (rec.get("roles") or {}).get("persist")
    if not rules:
        errors.append("role_routes.json has no persist role")
    elif any(r.get("mount") for r in rules):
        errors.append("role_routes.json persist mounts an engine")
    else:
        print("  ok role_routes.json persist")

    examined += 1
    seams = json.loads((root / SEAMS).read_text(encoding="utf-8")) if (root / SEAMS).is_file() else {}
    live = [r for r in (seams.get("live") or []) if r.get("id") == "persist"]
    unbuilt = [r for r in (seams.get("decided_unbuilt") or []) if r.get("id") == "persist"]
    if unbuilt:
        errors.append("persist is still decided-unbuilt")
    if not live:
        errors.append("persist missing from live")
    else:
        row = live[0]
        auth = (row.get("authoritative_for") or "")
        if "RES metadata" in auth or "implements RES" in auth:
            errors.append("persist authoritative_for still names RES as the job")
        if row.get("domain_writer") is True:
            errors.append("persist must not be domain_writer")
        served = row.get("served_by") or []
        if not any("persist_cpcp_controller.rb" in s for s in served):
            errors.append("persist live must be served by persist_cpcp_controller.rb")
        print("  ok persist live, not RES, not domain_writer")

    examined += 1
    ctl = (root / CONTROLLER).read_text(encoding="utf-8", errors="replace") if (root / CONTROLLER).is_file() else ""
    if not ctl:
        errors.append("missing %s" % CONTROLLER.as_posix())
    else:
        if "persist.path.set" not in ctl or "persist.path.get" not in ctl:
            errors.append("controller missing persist.path.set/get")
        if "def dispatch" in code_only(ctl):
            errors.append("PersistCpcpController overrides #dispatch")
        print("  ok PersistCpcpController")

    examined += 1
    writers = json.loads((root / WRITERS).read_text(encoding="utf-8")) if (root / WRITERS).is_file() else {}
    spec = (writers.get("roles") or {}).get("persist")
    if spec is None:
        errors.append("domain_writers.json has no persist role")
    elif spec.get("writes") == "all_domain":
        errors.append("persist writes all_domain")
    elif spec.get("writes") != ["PersistPlacement"]:
        errors.append("persist writes must be [PersistPlacement], got %r" % spec.get("writes"))
    else:
        print("  ok domain_writers persist writes PersistPlacement")

    examined += 1
    for rel in BACK_CLIENTS:
        examined += 1
        p = root / rel
        text = p.read_text(encoding="utf-8", errors="replace") if p.is_file() else ""
        if "http://persist" in text:
            errors.append("%s dials persist (BACK completes without persist)" % rel.as_posix())
        else:
            print("  ok %s does not dial persist" % rel.as_posix())

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("ROLE PERSIST FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("role persist: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
