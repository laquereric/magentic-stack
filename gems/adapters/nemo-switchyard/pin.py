#!/usr/bin/env python3
"""Read the Switchyard pin record.

submodule_path is the pin.json field (upstreams/manifests/nemo-switchyard.pin.json).
Do not hardcode the gitlink.
"""
from __future__ import annotations

import json
from pathlib import Path

PIN_REL = Path("upstreams/manifests/nemo-switchyard.pin.json")


def load_pin(root: Path) -> dict:
    path = root / PIN_REL
    data = json.loads(path.read_text(encoding="utf-8"))
    sub = (data.get("submodule_path") or "").strip()
    sha = (data.get("pinned_revision") or "").strip()
    if not sub:
        raise SystemExit("pin.json submodule_path is empty")
    if not sha:
        raise SystemExit("pin.json pinned_revision is empty")
    return data


def submodule_path(root: Path) -> str:
    return load_pin(root)["submodule_path"].strip()


def pinned_revision(root: Path) -> str:
    return load_pin(root)["pinned_revision"].strip()
