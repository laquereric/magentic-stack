#!/usr/bin/env python3
"""Read the genai-prices data pin. Do not hardcode the digest."""
from __future__ import annotations

import json
from pathlib import Path

PIN_REL = Path("upstreams/manifests/genai-prices.pin.json")


def load_pin(root: Path) -> dict:
    path = root / PIN_REL
    data = json.loads(path.read_text(encoding="utf-8"))
    ver = str(data.get("pinned_version") or "").strip()
    digest = str(data.get("data_sha256") or "").strip()
    rel = str(data.get("data_file") or "").strip()
    if not ver or ver == "PENDING":
        raise SystemExit("pin.json pinned_version is empty")
    if len(digest) != 64:
        raise SystemExit("pin.json data_sha256 is not 64-hex")
    if not rel:
        raise SystemExit("pin.json data_file is empty")
    return data


def pinned_version(root: Path) -> str:
    return str(load_pin(root)["pinned_version"]).strip()


def data_sha256(root: Path) -> str:
    return str(load_pin(root)["data_sha256"]).strip()
