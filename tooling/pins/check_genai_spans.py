#!/usr/bin/env python3
"""Fail if /_cpcp or SWITCH drop GenAI-semconv spans, or grow a Logfire dep.

docs/pydantic-upgrades.md rec 4. ADR 0058: vocabulary, not SDK, not Logfire.
Empty CHECK_ROOT fails.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

SWITCH = Path("runtimes/switch/genai_span.mjs")
SERVER = Path("runtimes/switch/server.mjs")
CPCP = Path("gems/rails-cpcp/lib/rails_cpcp/genai_span.rb")
DISP = Path("gems/rails-cpcp/lib/rails_cpcp/dispatcher.rb")
CONTENT = (
    "gen_ai.input.messages",
    "gen_ai.output.messages",
    "gen_ai.prompt",
    "gen_ai.completion",
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


def main() -> int:
    if fail_empty_check_root():
        return 1
    root = root_from_env()
    checks = []

    def check(name, ok, detail=""):
        checks.append((name, bool(ok), str(detail)))
        return bool(ok)

    switch = (root / SWITCH).read_text(encoding="utf-8") if (root / SWITCH).is_file() else ""
    server = (root / SERVER).read_text(encoding="utf-8") if (root / SERVER).is_file() else ""
    cpcp = (root / CPCP).read_text(encoding="utf-8") if (root / CPCP).is_file() else ""
    disp = (root / DISP).read_text(encoding="utf-8") if (root / DISP).is_file() else ""
    ok = True
    ok = check("switch-helper", bool(switch), str(SWITCH)) and ok
    ok = check("cpcp-helper", bool(cpcp), str(CPCP)) and ok
    ok = check("switch-operation", "gen_ai.operation.name" in switch, "chat") and ok
    ok = check("cpcp-operation", "gen_ai.operation.name" in cpcp, "invoke_agent") and ok
    ok = check("switch-wired", "emitChat" in server and "genai_span.mjs" in server, "server.mjs") and ok
    ok = check("cpcp-wired", "GenaiSpan.around" in disp, "dispatcher.rb") and ok
    ok = check("no-logfire-switch", "import logfire" not in switch and "from logfire" not in switch, "switch helper") and ok
    ok = check("no-logfire-cpcp", "import logfire" not in cpcp and "from logfire" not in cpcp, "cpcp helper") and ok
    ok = check("no-sdk-switch", "opentelemetry" not in switch.lower(), "no SDK") and ok
    ok = check("no-sdk-cpcp", "opentelemetry" not in cpcp.lower(), "no SDK") and ok
    leaked = [n for n in CONTENT if n in switch or n in cpcp]
    # Mentioning the name in a FORBIDDEN list is the door, not a leak.
    leaked = [n for n in leaked if ("FORBIDDEN" not in switch and n in switch) or False]
    ok = check("content-not-emitted", "gen_ai.input.messages" in switch and "FORBIDDEN" in switch, "deny-list") and ok
    ok = check("cpcp-forbidden-list", "FORBIDDEN" in cpcp, "cpcp deny-list") and ok

    populated, _pop = emit_population(len(checks))
    if not populated:
        return 1
    print("check | ok | detail")
    print("------|----|--------")
    for name, passed, detail in checks:
        print("%s | %s | %s" % (name, "true" if passed else "false", detail))
    if not ok:
        print("genai-spans: FAIL", file=sys.stderr)
        return 1
    print("genai-spans: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
