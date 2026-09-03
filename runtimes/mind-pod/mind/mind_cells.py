"""Per-cycle Python cells written by the LLM (row 10 follow-up).

NOOA runs LLM output as Jupyter-style code cells (LLMOutput events) in its
REPL. With DB_PATH bound those events already reach MIND's sqlite through
the storage backend; this module is the pod-level handle on them: extract
the cells from an agent's event log right after a cognition call, in
bounded form for the retained reading, and count them for the observation
log. Stdlib only (hashlib). No NOOA imports -- duck-type everything so the
sweep gate executes this on a bare interpreter.

Cells are DATA, never executed here. Nothing in them is true of the pod;
only an admitted proposal is.
"""
from __future__ import annotations

import hashlib

MAX_CELLS = 16
PREVIEW_CHARS = 240


def _type_name(event):
    if isinstance(event, dict):
        for key in ("type", "event_type", "kind"):
            value = event.get(key)
            if isinstance(value, str) and value:
                return value
        return ""
    name = type(event).__name__
    if name not in ("dict",):
        return name
    return ""


def _content(event):
    if isinstance(event, dict):
        value = event.get("content")
    else:
        value = getattr(event, "content", None)
    return value if isinstance(value, str) else ""


def from_events(events):
    """Bounded [{index, sha256, chars, preview}] for LLM-written Python."""
    out = []
    try:
        items = list(events or [])
    except TypeError:
        return []
    for event in items:
        if _type_name(event) != "LLMOutput":
            continue
        content = _content(event)
        if not content.strip():
            continue
        digest = hashlib.sha256(content.encode("utf-8")).hexdigest()
        out.append(
            {
                "index": len(out),
                "sha256": digest,
                "chars": len(content),
                "preview": content[:PREVIEW_CHARS],
            }
        )
        if len(out) >= MAX_CELLS:
            break
    return out


def _raw_outputs(agent):
    try:
        return list(agent.events.query(type="LLMOutput") or [])
    except Exception:
        return []


def count_outputs(agent):
    """LLMOutput events visible before a call. Cognition snapshots this and
    passes it back as skip: a manager that replays backend history must not
    attribute old cells to the new cycle (EventsApi returns chronological
    order, so a positional skip is sound)."""
    return len(_raw_outputs(agent))


def from_agent(agent, skip=0):
    """Cells from one cognition call's agent. Empty on any failure -- a
    missing cell list must never fail the cycle that produced the reading."""
    try:
        return from_events(_raw_outputs(agent)[max(0, skip):])
    except Exception:
        return []


def summarize(cells):
    return {"cells": len(cells), "chars": sum(c.get("chars", 0) for c in cells)}
