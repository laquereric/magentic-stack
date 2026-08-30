#!/usr/bin/env python3
"""Extract NodeShape source-text blocks without reflowing.

Shape TEXT is the exact byte slice from `Name a sh:NodeShape` through
(not including) the next shape start. Prefix headers are not part of
shape text. Used by the step-9 split and by the identity plant.
"""
from __future__ import annotations
import hashlib, json, re
from pathlib import Path

SHAPE_START = re.compile(
    r"^((?:[A-Za-z0-9_]+:)?[A-Za-z0-9_]+)\s+a\s+sh:NodeShape\b",
    re.M,
)


def local_name(token: str) -> str:
    token = token.rstrip("/").split("#")[-1].split("/")[-1]
    if ":" in token:
        token = token.split(":", 1)[-1]
    return token


def extract(text: str) -> tuple[str, list[dict]]:
    matches = list(SHAPE_START.finditer(text))
    if not matches:
        return text, []
    header = text[: matches[0].start()]
    blocks = []
    for i, m in enumerate(matches):
        end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        body = text[m.start() : end]
        name = local_name(m.group(1))
        blocks.append({
            "local_name": name,
            "text": body,
            "sha256": hashlib.sha256(body.encode("utf-8")).hexdigest(),
        })
    return header, blocks


def extract_file(path: Path) -> tuple[str, list[dict]]:
    return extract(path.read_text(encoding="utf-8"))
