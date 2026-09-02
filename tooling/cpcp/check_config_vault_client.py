#!/usr/bin/env python3
"""Fail if config-admin's vault client can get, or discards a non-200 body.

Gap 5 / 104. put+list only. Net::HTTP#request always parses the body.
urlopen / Net::HTTP.get would raise on 4xx and lose reason/because.
Do not "fix" by making vault return 200.

Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

CLIENT = Path("runtimes/mind-pod/app/app/services/config_admin/vault_client.rb")
CTRL = Path("runtimes/mind-pod/app/app/controllers/config_admin/secrets_controller.rb")
FORBIDDEN_HTTP = re.compile(r"urlopen|URI\.open|Net::HTTP\.get\b|Faraday")


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

    def code_only(body: str) -> str:
        return "\n".join(line.split("#", 1)[0] for line in body.splitlines())

    cpath = root / CLIENT
    examined += 1
    text = cpath.read_text(encoding="utf-8", errors="replace") if cpath.is_file() else ""
    code = code_only(text) if text else ""
    if not text:
        errors.append("missing %s" % CLIENT.as_posix())
    else:
        print("  ok %s" % CLIENT.as_posix())

    examined += 1
    if "vault.secret.put" not in code or "vault.secret.list" not in code:
        errors.append("client does not name vault.secret.put and vault.secret.list")
    else:
        print("  ok put and list named")

    examined += 1
    if re.search(r"ALLOWED\s*=\s*\{[^}]*vault\.secret\.get", code, re.S):
        errors.append("ALLOWED includes vault.secret.get (read-back asymmetry)")
    elif "/secrets/" in code and ":name" in code:
        errors.append("client has a /secrets/:name path (get)")
    else:
        print("  ok get is not an HTTP method")

    examined += 1
    if FORBIDDEN_HTTP.search(code):
        errors.append("client uses a helper that raises on 4xx (gap 104)")
    elif ".request(" not in code:
        errors.append("client does not call Net::HTTP#request (body on every status)")
    else:
        print("  ok request() so 4xx bodies are read")

    examined += 1
    if "parse_body" not in code and "JSON.parse" not in code:
        errors.append("client does not parse the HTTP body")
    else:
        print("  ok body parsed")

    examined += 1
    ctrl_path = root / CTRL
    ctrl = ctrl_path.read_text(encoding="utf-8", errors="replace") if ctrl_path.is_file() else ""
    if not ctrl:
        errors.append("missing %s" % CTRL.as_posix())
    elif ".get(" in ctrl or "vault.secret.get" in ctrl:
        errors.append("secrets controller calls get")
    elif "@refusal" not in ctrl:
        errors.append("controller does not surface a vault refusal")
    else:
        print("  ok controller has no get and surfaces refusal")

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("CONFIG VAULT CLIENT FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("config vault client: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
