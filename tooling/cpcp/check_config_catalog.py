#!/usr/bin/env python3
"""Fail if the catalogue is not owned by ROLE=config, or config executes it.

Gap 15 / 108. catalog.mjs data ports to ROLE=config. discovery.mjs and
verify.mjs stay on switch. Config may display; it may not egress or read
a token. Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

JSON_REL = Path("runtimes/mind-pod/app/config/llm_catalog.json")
SWITCH_COPY = Path("runtimes/switch/llm_catalog.json")
CATALOG_MJS = Path("runtimes/switch/catalog.mjs")
DISCOVERY = Path("runtimes/switch/discovery.mjs")
VERIFY = Path("runtimes/switch/verify.mjs")
DOCKER = Path("runtimes/switch/Dockerfile")
CATALOG_RB = Path("runtimes/mind-pod/app/app/services/config_admin/catalog.rb")
CATALOG_CTRL = Path("runtimes/mind-pod/app/app/controllers/config_admin/catalog_controller.rb")
ROUTES = Path("runtimes/mind-pod/app/config/routes.rb")
ROLE_ROUTES = Path("tooling/compose/role_routes.json")
VENDORS = ("ollama", "openai", "anthropic", "fireworks", "openrouter", "nvidia")
FORBIDDEN = re.compile(
    r"state\.keys|egress\(|vault\.secret\.get|discovery\.mjs|verify\.mjs|complete\("
)
INLINE_TABLE = re.compile(r"export\s+const\s+CATALOG\s*=\s*Object\.freeze\(\s*\{")
COMMENT = re.compile(r"#.*")


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


def code_only(text: str, hash_comment: bool) -> str:
    if not hash_comment:
        return text
    return "\n".join(COMMENT.sub("", line) for line in text.splitlines())


def js_code(text: str) -> str:
    no_block = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return "\n".join(re.sub(r"//.*", "", line) for line in no_block.splitlines())


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
    jpath = root / JSON_REL
    data = None
    if not jpath.is_file():
        errors.append("missing %s (ROLE=config owns the table)" % JSON_REL.as_posix())
    else:
        print("  ok %s" % JSON_REL.as_posix())
        try:
            data = json.loads(jpath.read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            errors.append("llm_catalog.json unparseable: %s" % e)
            data = {}

    examined += 1
    if (root / SWITCH_COPY).is_file():
        errors.append("%s exists -- a second copy of the table (dual home)" % SWITCH_COPY.as_posix())
    else:
        print("  ok no switch-source copy of the table")

    vendors = (data or {}).get("vendors") or {}
    examined += 1
    if (data or {}).get("owned_by") != "ROLE=config":
        errors.append("llm_catalog.json owned_by must be ROLE=config")
    missing = [v for v in VENDORS if v not in vendors]
    if missing:
        errors.append("catalog missing vendors %s" % missing)
    else:
        print("  ok six vendors, owned_by ROLE=config")

    examined += 1
    ollama = (vendors.get("ollama") or {}).get("models") or []
    by_id = {m.get("id"): m for m in ollama if isinstance(m, dict)}
    for mid in ("qwen2.5:3b", "llama3.2:1b"):
        row = by_id.get(mid) or {}
        if row.get("tools") is not False:
            errors.append("%s tools must be false (observed failure, not an assumption)" % mid)
    openrouter = (vendors.get("openrouter") or {}).get("models") or []
    if not openrouter:
        errors.append("openrouter has no seed models")
    for m in openrouter:
        mid = (m or {}).get("id") or ""
        if "/" not in mid:
            errors.append("openrouter id %s lacks vendor prefix" % mid)
        if m.get("in") is not None or m.get("out") is not None:
            errors.append("openrouter %s must leave price unknown" % mid)
    if ollama and openrouter:
        print("  ok tools filter and openrouter unknown prices")

    examined += 1
    mjs_path = root / CATALOG_MJS
    mjs = mjs_path.read_text(encoding="utf-8", errors="replace") if mjs_path.is_file() else ""
    if not mjs:
        errors.append("missing %s (routing helpers must stay; do not drop the file)" % CATALOG_MJS.as_posix())
    else:
        print("  ok %s" % CATALOG_MJS.as_posix())
    code = js_code(mjs)
    if INLINE_TABLE.search(code):
        errors.append("catalog.mjs still inlines the vendor table; the table moved to llm_catalog.json")
    if "readFileSync" not in code and "llm_catalog.json" not in mjs:
        errors.append("catalog.mjs does not load llm_catalog.json")
    for name in ("estimateCost", "estimateTokens", "modelSpec"):
        if ("function %s" % name) not in code and ("export function %s" % name) not in mjs:
            errors.append("catalog.mjs dropped routing helper %s" % name)
    if "state.keys" in code or "egress(" in code:
        errors.append("catalog.mjs reads a credential or egresses")
    if INLINE_TABLE.search(code) is None and "readFileSync" in code:
        print("  ok catalog.mjs loads JSON; helpers kept; no credential")

    examined += 1
    for rel, because in (
        (DISCOVERY, "hardcoded list that shipped a 404"),
        (VERIFY, "assumed tool support, an assumption that reads as a fact"),
    ):
        p = root / rel
        if not p.is_file():
            errors.append("missing %s (%s) -- do not drop any of the three" % (rel.as_posix(), because))
        else:
            print("  ok %s stays on switch" % rel.as_posix())

    examined += 1
    docker = (root / DOCKER).read_text(encoding="utf-8", errors="replace") if (root / DOCKER).is_file() else ""
    if "llm_catalog.json" not in docker:
        errors.append("switch Dockerfile does not COPY llm_catalog.json into the image")
    elif "mind-pod/app/config/llm_catalog.json" not in docker:
        errors.append("switch Dockerfile COPY must take the ROLE=config file, not a local duplicate")
    else:
        print("  ok switch image copies the config-owned file")

    examined += 1
    rb = (root / CATALOG_RB).read_text(encoding="utf-8", errors="replace") if (root / CATALOG_RB).is_file() else ""
    ctrl = (root / CATALOG_CTRL).read_text(encoding="utf-8", errors="replace") if (root / CATALOG_CTRL).is_file() else ""
    if not rb:
        errors.append("missing %s" % CATALOG_RB.as_posix())
    else:
        print("  ok %s" % CATALOG_RB.as_posix())
    if not ctrl:
        errors.append("missing %s" % CATALOG_CTRL.as_posix())
    else:
        print("  ok %s" % CATALOG_CTRL.as_posix())
    for label, body in (("catalog.rb", rb), ("catalog_controller.rb", ctrl)):
        code_rb = code_only(body, True)
        if FORBIDDEN.search(code_rb):
            errors.append("%s executes discovery/verify or reads a token" % label)

    examined += 1
    routes = (root / ROUTES).read_text(encoding="utf-8", errors="replace") if (root / ROUTES).is_file() else ""
    cfg = ""
    if "when \"config\"" in routes:
        cfg = routes.split('when "config"', 1)[1]
        nxt = re.search(r'\n  when "', cfg)
        if nxt:
            cfg = cfg[:nxt.start()]
    if 'get "/catalog"' not in cfg:
        errors.append("ROLE=config does not draw GET /catalog")
    if "/_cpcp" in cfg:
        errors.append("ROLE=config draws /_cpcp")
    if "secrets/:name" in cfg:
        errors.append("ROLE=config draws GET /secrets/:name (read-back)")
    if "discovery" in cfg.lower() and "stay" not in cfg.lower():
        errors.append("ROLE=config draws a discovery execute route")
    rec = {}
    rpath = root / ROLE_ROUTES
    if rpath.is_file():
        rec = json.loads(rpath.read_text(encoding="utf-8"))
    cfg_rules = (rec.get("roles") or {}).get("config") or []
    if not any(r.get("path") == "/catalog" and r.get("method") == "GET" for r in cfg_rules):
        errors.append("role_routes.json config is missing GET /catalog")
    else:
        print("  ok GET /catalog on ROLE=config; no get, no /_cpcp")

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("CONFIG CATALOG FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("config catalog: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
