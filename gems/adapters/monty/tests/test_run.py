#!/usr/bin/env python3
"""Stdlib tests for the monty adapter. No pydantic_monty required."""
from __future__ import annotations

import ast
import asyncio
import sys
import types
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[4]
ADAPTER = ROOT / "gems" / "adapters" / "monty"
sys.path.insert(0, str(ADAPTER.parent))

from monty.run import adapter_source, run  # noqa: E402


def test_empty_code():
    r = run("")
    assert r["ok"] is False
    assert r["reason"] == "empty_code"


def test_absent_is_typed():
    r = run("1 + 1")
    assert r["ok"] is False
    assert r["reason"] == "monty_absent"
    assert "CPython is not a fallback" in r["because"]


def test_source_has_no_inprocess_exec():
    tree = ast.parse(adapter_source())
    banned = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
            if node.func.id in {"exec", "eval", "compile"}:
                banned.append(node.func.id)
    assert banned == [], banned


def test_intercept_does_not_call_nxt():
    sys.path.insert(0, str(ROOT / "runtimes" / "mind-pod" / "mind"))
    import mind_codeact

    called = {"nxt": False}

    async def nxt(ctx):
        called["nxt"] = True
        return ctx

    class EM:
        def intercept(self, kind, fn):
            self.kind = kind
            self.fn = fn

    agent = SimpleNamespace(event_manager=EM())
    inst = mind_codeact.install(agent)
    assert inst["ok"] is True
    assert agent.event_manager.kind == "execute_python"
    ctx = SimpleNamespace(code="print(1)", result=None)
    asyncio.run(agent.event_manager.fn(ctx, nxt))
    assert called["nxt"] is False
    assert ctx.result is not None


def test_pin_loader():
    from monty.pin import load_pin, pinned_revision, submodule_path

    data = load_pin(ROOT)
    assert data["fork"] is False
    assert submodule_path(ROOT) == "upstreams/monty/src"
    assert len(pinned_revision(ROOT)) == 40


if __name__ == "__main__":
    failed = 0
    for name, fn in list(globals().items()):
        if name.startswith("test_") and callable(fn):
            try:
                fn()
                print("ok", name)
            except Exception as exc:
                failed += 1
                print("FAIL", name, exc)
    sys.exit(1 if failed else 0)
