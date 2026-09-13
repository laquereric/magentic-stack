"""Never-raise CodeAct execution through monty.

CPython is not a fallback. A missing binary, an unsupported construct, or
a host reach the sandbox was not given is a typed refusal. The adapter
does not import NOOA; MIND maps this envelope onto ExecutionResult.
"""
from __future__ import annotations

from pathlib import Path


def run(code, inputs=None):
    """Run `code` in monty. Returns {ok: true, ...} or {ok: false, reason, because}."""
    if not isinstance(code, str) or not code.strip():
        return {
            "ok": False,
            "reason": "empty_code",
            "because": "CodeAct cell is empty; nothing to isolate",
        }
    try:
        from pydantic_monty import CollectString, Monty
    except ImportError:
        return {
            "ok": False,
            "reason": "monty_absent",
            "because": "pydantic_monty is not installed; CPython is not a fallback",
        }
    try:
        collector = CollectString()
        with Monty() as pool:
            with pool.checkout(
                limits={"max_memory": 32_000_000, "max_duration_secs": 2.0}
            ) as session:
                result = session.feed_run(
                    code,
                    inputs=dict(inputs or {}),
                    print_callback=collector,
                )
        return {
            "ok": True,
            "stdout": getattr(collector, "output", "") or "",
            "result": result,
        }
    except Exception as exc:
        return _refuse(exc)


def _refuse(exc):
    name = type(exc).__name__
    msg = str(exc) or name
    reason = "cell_failed"
    if "Syntax" in name or "subset" in msg.lower() or "not implemented" in msg.lower():
        reason = "subset_refused"
    elif "Permission" in name or "not exist inside the sandbox" in msg:
        reason = "effect_denied"
    elif "Timeout" in name or "Memory" in name:
        reason = "resource_limit"
    elif "Conversion" in name:
        reason = "host_value_refused"
    return {"ok": False, "reason": reason, "because": msg}


def adapter_source():
    return Path(__file__).read_text(encoding="utf-8")
