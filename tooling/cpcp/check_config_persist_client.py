#!/usr/bin/env python3
"""Fail if config-admin's persist client can do more than set+get, or
discards a non-200 body.

Row 41. set+get only. Net::HTTP#request always parses the body.
urlopen / Net::HTTP.get would raise on 4xx and lose reason/because.
Do not "fix" by making persist return 200.

Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

CLIENT = Path("runtimes/mind-pod/app/app/services/config_admin/persist_client.rb")
CTRL = Path("runtimes/mind-pod/app/app/controllers/config_admin/placements_controller.rb")
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
    if "persist.path.set" not in code or "persist.path.get" not in code:
        errors.append("client does not name persist.path.set and persist.path.get")
    else:
        print("  ok set and get named")

    examined += 1
    if "_cpcp/rpc" not in code:
        errors.append("client does not POST /_cpcp/rpc (row 8 transport)")
    else:
        print("  ok transport is POST /_cpcp/rpc")

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
    if "ClosedSet" in code:
        errors.append("client builds its own path options (options live in the controller, from the closed set)")
    else:
        print("  ok transport carries no path invention")

    examined += 1
    ctrl_path = root / CTRL
    ctrl = ctrl_path.read_text(encoding="utf-8", errors="replace") if ctrl_path.is_file() else ""
    if not ctrl:
        errors.append("missing %s" % CTRL.as_posix())
    elif "PERSIST_URL" not in ctrl or "PERSIST_TOKEN" not in ctrl:
        errors.append("controller is not wired to PERSIST_URL/PERSIST_TOKEN")
    elif "@refusal" not in ctrl:
        errors.append("controller does not surface a persist refusal")
    elif "ClosedSet" not in ctrl:
        errors.append("controller does not source path options from the closed set")
    else:
        print("  ok controller wired to env, sources the closed set, surfaces refusal")

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("CONFIG PERSIST CLIENT FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("config persist client: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
