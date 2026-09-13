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
    import builtins

    real_import = builtins.__import__

    def blocked(name, *args, **kwargs):
        if name == "pydantic_monty" or name.startswith("pydantic_monty."):
            raise ImportError("blocked for test")
        return real_import(name, *args, **kwargs)

    saved = sys.modules.pop("pydantic_monty", None)
    builtins.__import__ = blocked
    try:
        r = run("1 + 1")
    finally:
        builtins.__import__ = real_import
        if saved is not None:
            sys.modules["pydantic_monty"] = saved
    assert r["ok"] is False
    assert r["reason"] == "monty_absent"
    assert "CPython is not a fallback" in r["because"]


def test_one_plus_one_when_wheel_present():
    try:
        import pydantic_monty  # noqa: F401
    except ImportError:
        return
    r = run("1 + 1")
    assert r["ok"] is True, r
    assert r["result"] == 2


def test_honors_monty_bin():
    src = adapter_source()
    assert "MONTY_BIN" in src
    assert "binary_path" in src


def test_source_has_no_inprocess_exec():
    tree = ast.parse(adapter_source())
    banned = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
            if node.func.id in {"exec", "eval", "compile"}:
                banned.append(node.func.id)
    assert banned == [], banned


def _agent_with_em():
    class EM:
        def intercept(self, kind, fn):
            self.kind = kind
            self.fn = fn

    return SimpleNamespace(event_manager=EM())


def test_intercept_does_not_call_nxt():
    sys.path.insert(0, str(ROOT / "runtimes" / "mind-pod" / "mind"))
    import mind_codeact

    called = {"nxt": False}

    async def nxt(ctx):
        called["nxt"] = True
        return ctx

    agent = _agent_with_em()
    inst = mind_codeact.install(agent)
    assert inst["ok"] is True
    assert agent.event_manager.kind == "execute_python"
    ctx = SimpleNamespace(code="print(1)", result=None)
    asyncio.run(agent.event_manager.fn(ctx, nxt))
    assert called["nxt"] is False
    assert ctx.result is not None


def test_adapter_absent_still_does_not_call_nxt():
    sys.path.insert(0, str(ROOT / "runtimes" / "mind-pod" / "mind"))
    import builtins
    import mind_codeact

    real_import = builtins.__import__

    def blocked(name, *args, **kwargs):
        if name == "monty" or name == "monty.run" or name.startswith("monty."):
            raise ImportError("blocked for test")
        return real_import(name, *args, **kwargs)

    saved = {k: sys.modules.pop(k) for k in list(sys.modules) if k == "monty" or k.startswith("monty.")}
    builtins.__import__ = blocked
    called = {"nxt": False}

    async def nxt(ctx):
        called["nxt"] = True
        return ctx

    try:
        agent = _agent_with_em()
        inst = mind_codeact.install(agent)
        assert inst["ok"] is True
        assert inst["reason"] == "installed_refusing"
        assert "CPython is not a fallback" in inst["because"]
        ctx = SimpleNamespace(code="print(1)", result=None)
        asyncio.run(agent.event_manager.fn(ctx, nxt))
        assert called["nxt"] is False
        assert ctx.result is not None
        envelope = ctx.result
        if isinstance(envelope, dict):
            assert envelope.get("reason") == "adapter_absent"
    finally:
        builtins.__import__ = real_import
        sys.modules.update(saved)


def test_prepare_adapter_only_does_not_need_nooa():
    import os
    import subprocess

    prepare = ROOT / "runtimes" / "mind-pod" / "mind" / "bin" / "prepare"
    dest = ROOT / "runtimes" / "mind-pod" / "mind" / "vendor" / "monty_adapter"
    r = subprocess.run(
        ["bash", str(prepare), "--adapter-only"],
        cwd=str(ROOT),
        env={**os.environ, "NOOA_SRC": "/nonexistent/nooa"},
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert r.returncode == 0, r.stderr
    assert (dest / "run.py").is_file()
    assert (dest / "__init__.py").is_file()
    assert (dest / "pin.py").is_file()
    assert not (dest / "tests").exists()
    assert "CPython is not a fallback" in (dest / "run.py").read_text(encoding="utf-8")


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
