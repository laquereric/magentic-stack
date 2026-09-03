#!/usr/bin/env python3
"""Fail if provider keys can live anywhere but vault.

Row 11 slice A. Switch fetches keys per use via vault.secret.get
(presence via list); the state file, the UI, and the discovery path hold
none. A vault miss reads exactly like no key (missing_credential) -- there
is no fallback credential. The .agent/secrets bind mount stays (row 46);
only key custody moved.

Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

VAULT = Path("runtimes/switch/vault.mjs")
SERVER = Path("runtimes/switch/server.mjs")
SOURCES = Path("runtimes/switch/sources.mjs")
DISCOVERY = Path("runtimes/switch/discovery.mjs")
UI = Path("runtimes/switch/ui/ui.js")
COMPOSE_FILES = (
    Path("runtimes/mind-pod/docker-compose.yml"),
    Path("runtimes/mind-pod/app/extract/compose.yml"),
)
CODE_FILES = (VAULT, SERVER, SOURCES, DISCOVERY)


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
    return "\n".join(line for line in text.splitlines() if not line.strip().startswith("//"))


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
    vault = (root / VAULT).read_text(encoding="utf-8", errors="replace") if (root / VAULT).is_file() else ""
    if not vault:
        errors.append("missing %s" % VAULT.as_posix())
    else:
        print("  ok %s" % VAULT.as_posix())
    vcode = code_only(vault)
    for token_word in ("vault.secret.get", "vault.secret.list", "switchyard."):
        examined += 1
        if token_word not in vcode:
            errors.append("vault client does not %s" % token_word)
    if all(t in vcode for t in ("vault.secret.get", "vault.secret.list")):
        print("  ok vault client gets values, lists presence")
    examined += 1
    if "writeFileSync" in vcode or "STATE_FILE" in vcode or "sources.json" in vcode:
        errors.append("vault client touches the state file")
    else:
        print("  ok vault client never touches the state file")

    for rel in (SERVER, SOURCES, DISCOVERY):
        examined += 1
        text = (root / rel).read_text(encoding="utf-8", errors="replace") if (root / rel).is_file() else ""
        if not text:
            errors.append("missing %s" % rel.as_posix())
            continue
        if "state.keys" in code_only(text):
            errors.append("%s reads file keys" % rel.as_posix())
        else:
            print("  ok %s holds no file keys" % rel.as_posix())

    examined += 1
    server = (root / SERVER).read_text(encoding="utf-8", errors="replace") if (root / SERVER).is_file() else ""
    scode = code_only(server)
    if "key_moved_to_vault" not in scode:
        errors.append("key set/clear is not refused with key_moved_to_vault")
    elif "state.keys[" in scode:
        errors.append("server still writes file keys")
    else:
        print("  ok key writes refused, none stored")

    examined += 1
    ui = (root / UI).read_text(encoding="utf-8", errors="replace") if (root / UI).is_file() else ""
    if not ui:
        errors.append("missing %s" % UI.as_posix())
    elif "Save key" in ui or "key.value" in ui:
        errors.append("switch UI still accepts key material")
    else:
        print("  ok switch UI takes no keys")

    for rel in COMPOSE_FILES:
        examined += 1
        p = root / rel
        text = p.read_text(encoding="utf-8", errors="replace") if p.is_file() else ""
        if not p.is_file():
            errors.append("missing %s" % rel.as_posix())
            continue
        m = re.search(r"^  switch:\s*$", text, re.M)
        if not m:
            errors.append("%s has no switch service" % rel.as_posix())
            continue
        rest = text[m.end():]
        nxt = re.search(r"^  [A-Za-z0-9_-]+:\s*$", rest, re.M)
        top = re.search(r"^[A-Za-z]", rest, re.M)
        cuts = [i.start() for i in (nxt, top) if i]
        svc = rest[: min(cuts)] if cuts else rest
        if "VAULT_URL" not in svc or "SWITCH_VAULT_TOKEN" not in svc:
            errors.append("%s switch service is not wired to vault" % rel.as_posix())
        elif ".agent/secrets" not in svc:
            errors.append("%s switch lost the state bind mount (row 46)" % rel.as_posix())
        else:
            print("  ok %s switch vault-wired, bind kept" % rel.as_posix())

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("SWITCHYARD VAULT KEYS FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("switchyard vault keys: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
