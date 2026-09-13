#!/usr/bin/env python3
"""Stdlib tests for the genai-prices overlay. Uses a fixture, not the 323k file."""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
ADAPTER = ROOT / "gems" / "adapters" / "genai-prices"
sys.path.insert(0, str(ADAPTER))

from overlay import overlay  # noqa: E402
from pin import data_sha256, load_pin, pinned_version  # noqa: E402


FIXTURE = [
    {
        "id": "openai",
        "name": "OpenAI",
        "api_pattern": "openai",
        "models": [
            {
                "id": "gpt-4o-mini",
                "match": {"equals": "gpt-4o-mini"},
                "prices": {"input_mtok": 0.15, "output_mtok": 0.6},
            }
        ],
    },
    {
        "id": "fireworks",
        "name": "Fireworks",
        "api_pattern": "fireworks",
        "models": [
            {
                "id": "llama-v3p1-8b-instruct",
                "match": {"equals": "accounts/fireworks/models/llama-v3p1-8b-instruct"},
                "prices": {"input_mtok": 0.2, "output_mtok": 0.2},
            }
        ],
    },
    {
        "id": "openrouter",
        "name": "OpenRouter",
        "api_pattern": "openrouter",
        "models": [
            {
                "id": "openai/gpt-4o-mini",
                "match": {"equals": "openai/gpt-4o-mini"},
                "prices": {"input_mtok": 0.15, "output_mtok": 0.6},
            }
        ],
    },
]


def catalog(**vendors):
    return {"schema": "llm-catalog/v0", "owned_by": "ROLE=config", "vendors": vendors}


def test_bad_catalog():
    r = overlay(None, FIXTURE)
    assert r["ok"] is False
    assert r["reason"] == "bad_catalog"


def test_local_untouched():
    cat = catalog(
        ollama={
            "kind": "local",
            "models": [{"id": "qwen2.5:3b", "in": 0, "out": 0}],
        }
    )
    r = overlay(cat, FIXTURE)
    assert r["ok"] is True
    assert r["catalog"]["vendors"]["ollama"]["models"][0]["in"] == 0
    assert r["updated"] == []


def test_openrouter_stays_unknown():
    cat = catalog(
        openrouter={
            "kind": "remote",
            "models": [{"id": "openai/gpt-4o-mini", "in": None, "out": None}],
        }
    )
    r = overlay(cat, FIXTURE)
    assert r["ok"] is True
    row = r["catalog"]["vendors"]["openrouter"]["models"][0]
    assert row["in"] is None and row["out"] is None
    assert any(s.get("reason") == "openrouter_stays_unknown" for s in r["skipped"])


def test_openai_overlay():
    cat = catalog(
        openai={
            "kind": "remote",
            "models": [{"id": "gpt-4o-mini", "in": 9, "out": 9}],
        }
    )
    r = overlay(cat, FIXTURE)
    assert r["ok"] is True
    row = r["catalog"]["vendors"]["openai"]["models"][0]
    assert row["in"] == 0.15
    assert row["out"] == 0.6
    assert cat["vendors"]["openai"]["models"][0]["in"] == 9


def test_fireworks_prefixed_id():
    cat = catalog(
        fireworks={
            "kind": "remote",
            "models": [
                {
                    "id": "accounts/fireworks/models/llama-v3p1-8b-instruct",
                    "in": None,
                    "out": None,
                }
            ],
        }
    )
    r = overlay(cat, FIXTURE)
    assert r["ok"] is True
    row = r["catalog"]["vendors"]["fireworks"]["models"][0]
    assert row["in"] == 0.2
    assert row["out"] == 0.2


def test_does_not_add_keys():
    cat = catalog(
        opencode={
            "kind": "remote",
            "models": [{"id": "mimo-v2.5-free", "note": "free"}],
        }
    )
    r = overlay(cat, FIXTURE)
    assert r["ok"] is True
    assert "in" not in r["catalog"]["vendors"]["opencode"]["models"][0]


def test_pin_loader():
    data = load_pin(ROOT)
    assert data["kind"] == "data"
    assert data["fork"] is False
    assert pinned_version(ROOT) == "0.1.6"
    assert len(data_sha256(ROOT)) == 64


def test_live_digest_matches_file():
    import hashlib

    raw = (ADAPTER / "data_slim.json").read_bytes()
    assert hashlib.sha256(raw).hexdigest() == data_sha256(ROOT)


def test_catalog_mjs_has_no_second_table():
    mjs = (ROOT / "runtimes" / "switch" / "catalog.mjs").read_text(encoding="utf-8")
    assert "data_slim.json" not in mjs
    assert "INDICATIVE" in mjs


def test_live_catalog_overlay_respects_gates():
    table = json.loads(
        (ROOT / "runtimes" / "mind-pod" / "app" / "config" / "llm_catalog.json").read_text(
            encoding="utf-8"
        )
    )
    r = overlay(table)
    assert r["ok"] is True, r
    vendors = r["catalog"]["vendors"]
    assert vendors["ollama"]["models"][0]["in"] == 0
    for m in vendors["openrouter"]["models"]:
        assert m.get("in") is None and m.get("out") is None
    fw = next(
        m
        for m in vendors["fireworks"]["models"]
        if m["id"] == "accounts/fireworks/models/llama-v3p1-8b-instruct"
    )
    assert fw["in"] == 0.2 and fw["out"] == 0.2
    seventy = next(
        m
        for m in vendors["fireworks"]["models"]
        if m["id"] == "accounts/fireworks/models/llama-v3p1-70b-instruct"
    )
    assert seventy["in"] is None and seventy["out"] is None


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
