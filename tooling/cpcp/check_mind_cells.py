#!/usr/bin/env python3
"""Fail if MIND's per-cycle Python cells are unwired, unbounded, or executed.

Row 10 follow-up. mind_cells.py extracts LLM-written code cells from an
agent's event log in bounded form; the harness retains them with every
reading and the seam serves them. Cells are DATA: this gate executes the
extraction on fixtures and asserts the module can never execute what it
reads. Anything the wiring gains must arrive with its checker update.

Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import ast
import hashlib
import importlib.util
import sys
from pathlib import Path
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

CELLS = Path("runtimes/mind-pod/mind/mind_cells.py")
HARNESS = Path("runtimes/mind-pod/mind/harness.py")
DOCKERFILE = Path("runtimes/mind-pod/mind/Dockerfile")
STDLIB = {"hashlib", "__future__"}


def fail_empty_check_root():
    import os

    if "CHECK_ROOT" in os.environ and not str(os.environ.get("CHECK_ROOT", "")).strip():
        print("FAIL: empty CHECK_ROOT", file=sys.stderr)
        return True
    return False


def root_from_env():
    import os

    raw = os.environ.get("CHECK_ROOT")
    if raw is None:
        return Path(__file__).resolve().parents[2]
    return Path(raw)


def load_cells(root):
    path = root / CELLS
    spec = importlib.util.spec_from_file_location("mind_cells_under_test", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _llmout(content):
    """Fake with the real event class name (duck-typing keys on it)."""
    cls = type("LLMOutput", (), {})
    obj = cls()
    obj.content = content
    return obj


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
    cpath = root / CELLS
    if not cpath.is_file():
        print("FAIL: missing %s" % CELLS.as_posix(), file=sys.stderr)
        emit_population(0)
        return 1
    src = cpath.read_text(encoding="utf-8")
    print("  ok %s" % CELLS.as_posix())

    examined += 1
    try:
        tree = ast.parse(src)
    except SyntaxError as e:
        errors.append("mind_cells.py does not parse: %s" % e)
        tree = None
    if tree is not None:
        got = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                got.update(a.name.split(".")[0] for a in node.names)
            elif isinstance(node, ast.ImportFrom):
                got.add((node.module or "").split(".")[0])
        got.discard("")
        extra = sorted(g for g in got if g not in STDLIB)
        if extra:
            errors.append("mind_cells.py imports beyond stdlib allowlist: %s" % extra)
        else:
            print("  ok stdlib-only imports")

    for token_word in ("exec(", "eval(", "compile("):
        examined += 1
        if token_word in src:
            errors.append("mind_cells.py contains %r (cells are data, never executed)" % token_word)
        else:
            print("  ok no %s: cells never execute" % token_word.rstrip("("))

    examined += 1
    try:
        mod = load_cells(root)
    except Exception as e:  # noqa: BLE001
        errors.append("mind_cells.py does not import clean: %s: %s" % (e.__class__.__name__, e))
        mod = None
    if mod is not None:
        print("  ok cells module imports without NOOA")

        examined += 1
        code = "x = 1\nprint(x)"
        cells = mod.from_events([_llmout(code)])
        want_sha = hashlib.sha256(code.encode()).hexdigest()
        if (len(cells) != 1 or cells[0]["sha256"] != want_sha
                or cells[0]["chars"] != len(code) or cells[0]["preview"] != code
                or cells[0]["index"] != 0):
            errors.append("object-style LLMOutput not extracted exactly: %r" % (cells,))
        else:
            print("  ok object-style cell extracted exactly")

        examined += 1
        cells = mod.from_events([
            {"type": "LLMOutput", "content": "y = 2"},
            {"type": "Message", "content": "not code"},
            {"type": "LLMOutput", "content": "   "},
            SimpleNamespace(),
        ])
        if len(cells) != 1 or cells[0]["preview"] != "y = 2":
            errors.append("dict-style filtering wrong: %r" % (cells,))
        else:
            print("  ok dict-style extracted, others and blanks ignored")

        examined += 1
        many = [_llmout("c%d = %d" % (i, i)) for i in range(17)]
        cells = mod.from_events(many)
        long_one = mod.from_events([_llmout("z" * 500)])
        if len(cells) != mod.MAX_CELLS or cells[-1]["index"] != mod.MAX_CELLS - 1:
            errors.append("cell count not bounded at %d" % mod.MAX_CELLS)
        elif len(long_one) != 1 or len(long_one[0]["preview"]) != mod.PREVIEW_CHARS:
            errors.append("preview not bounded at %d chars" % mod.PREVIEW_CHARS)
        elif mod.from_events(None) != []:
            errors.append("None input is not []")
        else:
            print("  ok bounds hold (count, preview, None)")

        examined += 1
        made = mod.from_events([_llmout("a = 1"), _llmout("b = 2")])
        if mod.summarize(made) != {"cells": 2, "chars": 10}:
            errors.append("summarize wrong: %r" % (mod.summarize(made),))
        else:
            print("  ok summarize counts cells and chars")

        examined += 1

        class FakeEvents:
            def __init__(self, items):
                self.items = items

            def query(self, **kwargs):
                assert kwargs.get("type") == "LLMOutput", kwargs
                return self.items

        class FakeAgent:
            def __init__(self, items):
                self.events = FakeEvents(items)

        old = [_llmout("old = 0")]
        new = [_llmout("new = 1")]
        got = mod.from_agent(FakeAgent(old + new), skip=1)
        if len(got) != 1 or got[0]["preview"] != "new = 1":
            errors.append("skip does not scope to the new cycle: %r" % (got,))
        elif mod.from_agent(object()) != []:
            errors.append("broken agent is not []")
        else:
            print("  ok skip scopes cycles, broken agents fail soft")

    examined += 1
    harness = (root / HARNESS).read_text(encoding="utf-8", errors="replace") if (root / HARNESS).is_file() else ""
    wired = 0
    for token_word in ("mind_cells", "from_agent", "python_cells", '"python"'):
        examined += 1
        if token_word not in harness:
            errors.append("harness.py never %s (cells unwired)" % token_word)
        else:
            wired += 1
    if wired == 4:
        print("  ok harness extracts, retains, and serves cells")

    examined += 1
    df = (root / DOCKERFILE).read_text(encoding="utf-8", errors="replace") if (root / DOCKERFILE).is_file() else ""
    df_code = "\n".join(ln for ln in df.splitlines() if not ln.strip().startswith("#"))
    if "mind_cells.py" not in df_code:
        errors.append("mind Dockerfile does not COPY mind_cells.py")
    else:
        print("  ok Dockerfile ships mind_cells.py")

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("MIND CELLS FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("mind cells: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
