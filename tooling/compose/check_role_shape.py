#!/usr/bin/env python3
"""Fail if ROLE=shape v1 retrieval is missing, overreaches, or lies.

ADR 0049 / ROLE_SHAPE.md §2. v1 is GET retrieval of ProfileCatalog.default
files by digest. POST rpc is not in v1. Enforcement stays in BACK.

  - entrypoint shape) exists and does not db:prepare
  - both compose files declare unpublished ROLE=shape
  - routes.rb when "shape" is GET-only; does not mount the engine
  - catalog comes from ProfileCatalog.default, grouped by digest
  - incomplete: true with honest because (not the false L8 SHAPE_MAP reason)
  - empty catalog is ok:false (shape_catalog_empty)
  - domain_writers shape writes []
  - CpcpAdapter.install! stays ROLE=back

Empty CHECK_ROOT fails. 0 examined is not a pass.
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
SURFACE = Path("runtimes/mind-pod/app/app/services/shape_surface.rb")
CONTROLLER = Path("runtimes/mind-pod/app/app/controllers/shape_controller.rb")
WRITERS = Path("runtimes/mind-pod/app/config/domain_writers.json")
OSI_INIT = Path("runtimes/mind-pod/app/config/initializers/osi_level_8.rb")
FALSE_REASON = "shapes-level-8 is not in SHAPE_MAP"
NEED_BECAUSE = (
    "P2-P8",
    "P10",
    "Shapes::Level8.catalog",
    "contextframe",
    "52",
    "osi-level-8-profiles",
    "publication",
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


def code_only(text: str) -> str:
    return "\n".join(line.split("#", 1)[0] for line in text.splitlines())


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
    ep_path = root / ENTRYPOINT
    ep = ep_path.read_text(encoding="utf-8", errors="replace") if ep_path.is_file() else ""
    branch = entrypoint_branch(ep, "shape")
    if not branch:
        errors.append("entrypoint has no shape) branch")
    elif "db:prepare" in branch:
        errors.append("ROLE=shape entrypoint runs db:prepare (retrieval is DBless)")
    else:
        print("  ok entrypoint shape) has no db:prepare")

    for rel in COMPOSE_FILES:
        examined += 1
        p = root / rel
        text = p.read_text(encoding="utf-8", errors="replace") if p.is_file() else ""
        if not p.is_file():
            errors.append("missing %s" % rel.as_posix())
            continue
        svc = compose_service(text, "shape")
        if not svc:
            errors.append("%s has no shape service" % rel.as_posix())
            continue
        if not re.search(r"ROLE:\s*shape\b", svc):
            errors.append("%s shape service does not set ROLE: shape" % rel.as_posix())
        if re.search(r"^\s+ports:", svc, re.M):
            errors.append("%s shape service is host-published (gap 61; v1 is pod-internal)" % rel.as_posix())
        if "expose" not in svc:
            errors.append("%s shape service has no expose" % rel.as_posix())
        else:
            print("  ok %s shape unpublished" % rel.as_posix())

    examined += 1
    routes_path = root / ROUTES
    routes = routes_path.read_text(encoding="utf-8", errors="replace") if routes_path.is_file() else ""
    shape_case = role_case(routes, "shape")
    if not shape_case:
        errors.append('routes.rb has no when "shape"')
    else:
        shape_code = code_only(shape_case)
        if "RailsCpcp::Engine" in shape_code:
            errors.append("ROLE=shape mounts RailsCpcp::Engine (would draw POST rpc + note.create)")
        if "note.create" in shape_code:
            errors.append("ROLE=shape draws note.create")
        if "_cpcp/rpc" in shape_code:
            errors.append("ROLE=shape draws POST rpc (not in v1)")
        for needle in ('get "/_cpcp/up"', 'get "/_cpcp/shapes.json"', 'get "/_cpcp/shapes/:digest"'):
            if needle not in shape_case:
                errors.append("ROLE=shape missing %s" % needle)
        print("  ok routes.rb shape is GET-only")

    examined += 1
    rec_path = root / RECORD
    if not rec_path.is_file():
        errors.append("missing %s" % RECORD.as_posix())
    else:
        data = json.loads(rec_path.read_text(encoding="utf-8"))
        shape_rules = (data.get("roles") or {}).get("shape")
        if shape_rules is None:
            errors.append("role_routes.json has no shape role")
        else:
            labels = []
            for rule in shape_rules:
                if rule.get("mount"):
                    errors.append("role_routes.json shape mounts %s (engine mount draws rpc)" % rule["mount"])
                    labels.append("MOUNT %s" % rule["mount"])
                else:
                    labels.append("%s %s" % (rule.get("method"), rule.get("path")))
            want = {
                "GET /_cpcp/up",
                "GET /_cpcp/shapes.json",
                "GET /_cpcp/shapes/:digest",
            }
            have = set(labels)
            for w in sorted(want - have):
                errors.append("role_routes.json shape missing %s" % w)
            extra = have - want
            for e in sorted(extra):
                errors.append("role_routes.json shape extra %s" % e)
            print("  ok role_routes.json shape GET-only")

    examined += 1
    surf_path = root / SURFACE
    surf = surf_path.read_text(encoding="utf-8", errors="replace") if surf_path.is_file() else ""
    if not surf:
        errors.append("missing %s" % SURFACE.as_posix())
    else:
        if "ProfileCatalog.default" not in surf:
            errors.append("ShapeSurface does not read ProfileCatalog.default")
        if "Shapes::Level8.catalog" in surf and "empty stub" not in surf:
            errors.append("ShapeSurface uses Shapes::Level8.catalog as the resolver")
        if 'EMPTY' not in surf or "shape_catalog_empty" not in surf:
            errors.append("ShapeSurface missing EMPTY / shape_catalog_empty")
        if re.search(r'EMPTY\s*=\s*\{[^}]*"ok"\s*=>\s*true', surf, re.S):
            errors.append("empty catalog answering ok:true (the named failure mode)")
        if '"incomplete" => true' not in surf and '"incomplete" =>true' not in surf:
            errors.append("ShapeSurface does not declare incomplete: true")
        because_m = re.search(r"INCOMPLETE_BECAUSE = \[(.*?)\]\.freeze", surf, re.S)
        because_block = because_m.group(1) if because_m else ""
        if FALSE_REASON in because_block:
            errors.append("incomplete_because uses the false reason %r" % FALSE_REASON)
        for tok in NEED_BECAUSE:
            if tok not in surf:
                errors.append("incomplete_because missing honest token %r" % tok)
        if "UNMIGRATED = 52" not in surf and '"unmigrated" => 52' not in surf:
            errors.append("ShapeSurface does not declare unmigrated 52")
        print("  ok ShapeSurface from ProfileCatalog.default, incomplete, empty=ok:false")

    examined += 1
    ctl_path = root / CONTROLLER
    ctl = ctl_path.read_text(encoding="utf-8", errors="replace") if ctl_path.is_file() else ""
    if not ctl:
        errors.append("missing %s" % CONTROLLER.as_posix())
    else:
        if "text/turtle" not in ctl:
            errors.append("ShapeController does not serve text/turtle")
        if "not_found" not in ctl and "404" not in ctl:
            errors.append("ShapeController digest mismatch is not 404")
        if "note.create" in code_only(ctl):
            errors.append("ShapeController names note.create")
        print("  ok ShapeController turtle + 404")

    examined += 1
    wpath = root / WRITERS
    if not wpath.is_file():
        errors.append("missing %s" % WRITERS.as_posix())
    else:
        writers = json.loads(wpath.read_text(encoding="utf-8"))
        spec = (writers.get("roles") or {}).get("shape")
        if spec is None:
            errors.append("domain_writers.json has no shape role")
        elif spec.get("writes") != []:
            errors.append("domain_writers.json shape writes must be [], got %r" % spec.get("writes"))
        else:
            print("  ok domain_writers shape writes []")

    examined += 1
    init_path = root / OSI_INIT
    init = init_path.read_text(encoding="utf-8", errors="replace") if init_path.is_file() else ""
    if not init:
        errors.append("missing %s" % OSI_INIT.as_posix())
    elif "CpcpAdapter.install!" not in init:
        errors.append("CpcpAdapter.install! missing (enforcement must stay in BACK)")
    elif not re.search(r'CpcpAdapter\.install!.*if ENV\.fetch\("ROLE", "back"\) == "back"', init):
        errors.append("CpcpAdapter.install! is not gated to ROLE=back")
    else:
        print("  ok Grounding/CpcpAdapter stays ROLE=back")

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("ROLE SHAPE FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("role shape: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
