"""Install monty as NOOA's execute_python intercept.

Wraps CodeAct (ADR 0070). Does not fork NOOA: the documented intercept
is the door. Does not call nxt, so CPython is not a fallback.

mind_cells.py stays DATA. This module is the execution path.
The adapter lives at gems/adapters/monty; PYTHONPATH or a vendor copy
makes `import monty` resolve to that package, not the worker binary.
"""
from __future__ import annotations


def install(agent):
    """Register the intercept on `agent`. Never-raise envelope."""
    try:
        em = agent.event_manager
    except Exception:
        return {
            "ok": False,
            "reason": "no_event_manager",
            "because": "agent has no event_manager; cannot wrap CodeAct",
        }
    try:
        from monty.run import run as monty_run
    except ImportError:
        return {
            "ok": False,
            "reason": "adapter_absent",
            "because": "gems/adapters/monty is not on PYTHONPATH",
        }

    async def execute_python_intercept(ctx, nxt):
        # nxt is NOOA's in-process exec. Do not call it.
        envelope = monty_run(getattr(ctx, "code", "") or "")
        ctx.result = _as_execution_result(envelope)
        return ctx

    try:
        em.intercept("execute_python", execute_python_intercept)
    except Exception as exc:
        return {
            "ok": False,
            "reason": "intercept_failed",
            "because": str(exc),
        }
    return {"ok": True, "reason": "installed"}


def _as_execution_result(envelope):
    try:
        from nooa.events import ExecutionResult
    except ImportError:
        return envelope
    if envelope.get("ok"):
        return ExecutionResult(
            stdout=envelope.get("stdout") or "",
            returned_value=envelope.get("result"),
        )
    because = envelope.get("because") or envelope.get("reason") or "monty refused"
    return ExecutionResult(error=RuntimeError(because), stderr=because)
