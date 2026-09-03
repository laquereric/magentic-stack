#!/usr/bin/env python3
"""Fail if Switchyard v1 enables judge/escalation, stops forwarding, or opens a port.

Row 11 v1 / SWITCHYARD.md Shape D / ADR 0019. Content-blind means CONFIG:
allowed algorithm types are noop, passthrough, random. llm_classifier
(judge) and stage_router (escalation) must not appear as route types.
Node leftover reverse-fronts /v1 to the pin; router.mjs is not the
data-plane decision. Same compose service; 8789 unpublished, 8790
published; no new ports.

submodule_path is read from upstreams/manifests/nemo-switchyard.pin.json.
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

PIN = Path("upstreams/manifests/nemo-switchyard.pin.json")
ADAPTER = Path("gems/adapters/nemo-switchyard")
TOML = ADAPTER / "content-blind.toml"
SERVER = Path("runtimes/switch/server.mjs")
LANGUAGE = Path("tooling/compose/language_rule.json")
COMPOSE_FILES = (
    Path("runtimes/mind-pod/docker-compose.yml"),
    Path("runtimes/mind-pod/app/extract/compose.yml"),
)
ALLOWED = frozenset({"noop", "passthrough", "random"})
FORBIDDEN = frozenset({"llm_classifier", "stage_router"})
TYPE_RE = re.compile(r'(?m)^\s*type\s*=\s*"([^"]+)"')
MODE_RE = re.compile(r'(?m)^\s*mode\s*=\s*"([^"]+)"')


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


def compose_service(text: str, name: str) -> str:
    m = re.search(r"^  %s:\s*$" % re.escape(name), text, re.M)
    if not m:
        return ""
    rest = text[m.end():]
    nxt = re.search(r"^  [A-Za-z0-9_-]+:\s*$", rest, re.M)
    return rest[: nxt.start()] if nxt else rest


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
    pin_path = root / PIN
    pin = {}
    if not pin_path.is_file():
        errors.append("missing %s" % PIN.as_posix())
    else:
        try:
            pin = json.loads(pin_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            errors.append("pin.json is not JSON: %s" % e)
            pin = {}
        sub = (pin.get("submodule_path") or "").strip()
        if not sub:
            errors.append("pin.json submodule_path empty")
        else:
            print("  ok submodule_path from pin.json")
            examined += 1
            df_path = root / ADAPTER / "Dockerfile"
            df = df_path.read_text(encoding="utf-8", errors="replace") if df_path.is_file() else ""
            if not df:
                errors.append("missing %s" % (ADAPTER / "Dockerfile").as_posix())
            elif ("COPY %s/" % sub) not in df:
                errors.append("adapter Dockerfile COPY is not pin.json submodule_path")
            else:
                print("  ok Dockerfile COPY uses pin.json submodule_path")
        sha = (pin.get("pinned_revision") or "").strip()
        if not sha:
            errors.append("pin.json pinned_revision empty")

    examined += 1
    toml_path = root / TOML
    toml = toml_path.read_text(encoding="utf-8", errors="replace") if toml_path.is_file() else ""
    if not toml:
        errors.append("missing %s" % TOML.as_posix())
    else:
        code = "\n".join(line.split("#", 1)[0] for line in toml.splitlines())
        types = TYPE_RE.findall(code)
        if not types:
            errors.append("%s declares no route type" % TOML.as_posix())
        for t in types:
            if t in FORBIDDEN or t not in ALLOWED:
                errors.append("%s enables algorithm type %s" % (TOML.as_posix(), t))
        modes = MODE_RE.findall(code)
        if any(m in ("escalation", "capability") for m in modes):
            errors.append("%s enables classifier mode %s" % (TOML.as_posix(), modes))
        print("  ok %s types=%s" % (TOML.as_posix(), ",".join(types)))

    adapter_dir = root / ADAPTER
    if adapter_dir.is_dir():
        for p in sorted(adapter_dir.rglob("*")):
            if not p.is_file():
                continue
            if p.suffix not in {".toml", ".mjs", ".sh", ".py"}:
                continue
            examined += 1
            text = p.read_text(encoding="utf-8", errors="replace")
            rel = p.relative_to(root).as_posix()
            for t in TYPE_RE.findall(text):
                if t in FORBIDDEN or (p.suffix == ".toml" and t not in ALLOWED):
                    errors.append("%s assigns type %s" % (rel, t))
            for name in FORBIDDEN:
                if ('type = "%s"' % name) in text or ("type = '%s'" % name) in text:
                    errors.append("%s assigns type %s" % (rel, name))
            if MODE_RE.search(text) and any(
                m in ("escalation", "capability") for m in MODE_RE.findall(text)
            ):
                errors.append("%s assigns a classifier mode" % rel)

    examined += 1
    server_path = root / SERVER
    server = server_path.read_text(encoding="utf-8", errors="replace") if server_path.is_file() else ""
    if not server:
        errors.append("missing %s" % SERVER.as_posix())
    else:
        if re.search(r"route\s+as\s+routeQuery|routeQuery\(", server):
            errors.append("server.mjs still uses router.mjs as the data-plane decision")
        else:
            print("  ok server.mjs does not call routeQuery")
        if "SWITCHYARD_PIN_URL" not in server and "127.0.0.1:4000" not in server:
            errors.append("server.mjs does not forward /v1 to the pin")
        else:
            print("  ok server.mjs forwards to the pin")

    examined += 1
    lang_path = root / LANGUAGE
    if not lang_path.is_file():
        errors.append("missing %s" % LANGUAGE.as_posix())
    else:
        rule = json.loads(lang_path.read_text(encoding="utf-8"))
        viol = [v for v in (rule.get("violations") or []) if v.get("service") == "switch"]
        if not viol or viol[0].get("kind") != "violation":
            errors.append("language_rule.json dropped the switch violation")
        elif viol[0].get("observed") != "node" or viol[0].get("target") != "rust":
            errors.append("language_rule.json converted the switch violation")
        else:
            print("  ok switch remains a language violation")

    for rel in COMPOSE_FILES:
        examined += 1
        p = root / rel
        text = p.read_text(encoding="utf-8", errors="replace") if p.is_file() else ""
        if not text:
            errors.append("missing %s" % rel.as_posix())
            continue
        block = compose_service(text, "switch")
        if not block:
            errors.append("%s has no switch service" % rel.as_posix())
            continue
        if re.search(r"^\s+ports:", block, re.M):
            errors.append("%s switch UI plane is host-published (row 11 slice C retired :13001)" % rel.as_posix())
        else:
            print("  ok %s switch publishes nothing" % rel.as_posix())
        if '"8789"' not in block and "'8789'" not in block:
            errors.append("%s switch dropped unpublished 8789" % rel.as_posix())
        if re.search(r"4000", block) and re.search(r"ports:", block):
            # loopback 4000 must not be published. Env SWITCHYARD_PIN_PORT=4000
            # is internal; a host mapping of 4000 is the failure.
            if re.search(r'ports:.*4000|"4000:|4000:4000|4000:8789|8789:4000', block, re.S):
                errors.append("%s publishes pin port 4000" % rel.as_posix())
        dockerfile = "gems/adapters/nemo-switchyard/Dockerfile"
        if dockerfile not in block:
            errors.append("%s switch dockerfile is not the adapter" % rel.as_posix())
        else:
            print("  ok %s adapter dockerfile" % rel.as_posix())

    populated, pop = emit_population(examined)
    if not populated:
        return 1
    if errors:
        for e in errors:
            print("FAIL: %s" % e, file=sys.stderr)
        print(json.dumps({"gate": "switchyard-algorithms", "status": "fail", "population": pop, "errors": errors}, indent=2))
        return 1
    print("OK switchyard-algorithms (%d examined)" % examined)
    return 0


if __name__ == "__main__":
    sys.exit(main())
