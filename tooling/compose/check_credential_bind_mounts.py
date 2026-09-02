#!/usr/bin/env python3
"""Fail if credential stores become named volumes while 0046:85 stands.

Gap 46 / 113. Analysis, not conversion. Vault and switch keys are JSON
files on bind mounts so they survive `docker compose down -v`. They are
not SQLite; the virtiofs detector does not apply.

Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

COMPOSE = (
    "runtimes/mind-pod/docker-compose.yml",
    "runtimes/mind-pod/app/extract/compose.yml",
)
STORE = Path("runtimes/mind-pod/app/app/services/vault/store.rb")
SOURCES = Path("runtimes/switch/sources.mjs")
ADR = Path("docs/adr/0046-vault-is-not-the-config-ui.md")
SQLITE = re.compile(r"sqlite3|\.sqlite3\b", re.I)


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

    for rel in COMPOSE:
        examined += 1
        path = root / rel
        text = path.read_text(encoding="utf-8", errors="replace") if path.is_file() else ""
        if not text:
            errors.append("missing %s" % rel)
            continue
        print("  ok %s" % rel)
        if ".agent/vault:" not in text.replace(" ", ""):
            # allow spaces around colon
            if not re.search(r"\.agent/vault\s*:", text):
                errors.append("%s does not bind .agent/vault (0046:85)" % rel)
        if ".agent/secrets:" not in text.replace(" ", ""):
            if not re.search(r"\.agent/secrets\s*:", text):
                errors.append("%s does not bind .agent/secrets (0046:85)" % rel)
        if re.search(r"VAULT_STORE_PATH:.*\.sqlite", text):
            errors.append("%s VAULT_STORE_PATH is sqlite, not secrets.json" % rel)
        elif "secrets.json" not in text:
            errors.append("%s missing secrets.json store path" % rel)

    examined += 1
    store = (root / STORE).read_text(encoding="utf-8", errors="replace") if (root / STORE).is_file() else ""
    if not store:
        errors.append("missing %s" % STORE.as_posix())
    else:
        print("  ok %s" % STORE.as_posix())
    code = "\n".join(line.split("#", 1)[0] for line in store.splitlines())
    if SQLITE.search(code):
        errors.append("Vault::Store uses sqlite; the virtiofs reason would then apply")
    if "JSON.parse" not in code or "JSON.generate" not in code:
        errors.append("Vault::Store is not a JSON file store")
    if "File.rename" not in code:
        errors.append("Vault::Store persist is not tmp+rename")

    examined += 1
    src = (root / SOURCES).read_text(encoding="utf-8", errors="replace") if (root / SOURCES).is_file() else ""
    if not src:
        errors.append("missing %s" % SOURCES.as_posix())
    else:
        print("  ok %s" % SOURCES.as_posix())
    if "sources.json" not in src:
        errors.append("switch state file is not sources.json")
    if SQLITE.search(src):
        errors.append("sources.mjs uses sqlite")

    examined += 1
    adr = (root / ADR).read_text(encoding="utf-8", errors="replace") if (root / ADR).is_file() else ""
    if not adr:
        errors.append("missing %s" % ADR.as_posix())
    else:
        print("  ok %s" % ADR.as_posix())
    if "survive" not in adr or "down -v" not in adr:
        errors.append("0046 no longer says keys must survive docker compose down -v")
    if "named volume is not acceptable" not in adr:
        errors.append("0046 no longer says a named volume is not acceptable")
    else:
        print("  ok 0046:85 still forbids named volumes for keys")

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("CREDENTIAL BIND MOUNTS FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("credential bind mounts: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
