"""Never-raise overlay of genai-prices onto the ROLE=config catalog.

Does not invent a second table. catalog.mjs still loads only
llm_catalog.json. This adapter writes `in`/`out` on models that
already have those keys. CPython is not involved; this is data.

Skip:
  - vendor.kind == local (zeros are "not billed", not a price)
  - openrouter (check_config_catalog requires unknown prices)
  - models with no `in`/`out` keys (opencode seed notes)
"""
from __future__ import annotations

import copy
import json
import re
from pathlib import Path

ADAPTER_DIR = Path(__file__).resolve().parent
DATA_SLIM = ADAPTER_DIR / "data_slim.json"
SKIP_VENDORS = frozenset({"openrouter"})


def overlay(catalog, prices=None):
    """Return {ok: true, catalog, updated, skipped} or a refusal envelope."""
    if not isinstance(catalog, dict) or not isinstance(catalog.get("vendors"), dict):
        return {
            "ok": False,
            "reason": "bad_catalog",
            "because": "catalog must be an object with a vendors map",
        }
    try:
        table = prices if prices is not None else _load_prices()
    except Exception as exc:
        return {
            "ok": False,
            "reason": "prices_absent",
            "because": str(exc) or "data_slim.json unreadable",
        }
    providers = _providers(table)
    if providers is None:
        return {
            "ok": False,
            "reason": "bad_prices",
            "because": "data_slim.json must be a list of providers",
        }

    out = copy.deepcopy(catalog)
    updated = []
    skipped = []
    for vendor_id, vendor in (out.get("vendors") or {}).items():
        if not isinstance(vendor, dict):
            skipped.append({"vendor": vendor_id, "reason": "not_an_object"})
            continue
        if vendor.get("kind") == "local":
            skipped.append({"vendor": vendor_id, "reason": "local"})
            continue
        if vendor_id in SKIP_VENDORS:
            skipped.append({"vendor": vendor_id, "reason": "openrouter_stays_unknown"})
            continue
        provider = providers.get(vendor_id)
        if provider is None:
            skipped.append({"vendor": vendor_id, "reason": "no_provider"})
            continue
        for model in vendor.get("models") or []:
            if not isinstance(model, dict) or "in" not in model or "out" not in model:
                continue
            mid = str(model.get("id") or "")
            hit = _match_model(provider, mid)
            if hit is None:
                skipped.append({"vendor": vendor_id, "model": mid, "reason": "no_match"})
                continue
            pair = _mtok_pair(hit.get("prices"))
            if pair is None:
                skipped.append({"vendor": vendor_id, "model": mid, "reason": "no_mtok"})
                continue
            inn, outp = pair
            if model.get("in") == inn and model.get("out") == outp:
                continue
            model["in"] = inn
            model["out"] = outp
            updated.append({"vendor": vendor_id, "model": mid, "in": inn, "out": outp})
    return {"ok": True, "catalog": out, "updated": updated, "skipped": skipped}


def _load_prices():
    return json.loads(DATA_SLIM.read_text(encoding="utf-8"))


def _providers(table):
    if not isinstance(table, list):
        return None
    out = {}
    for row in table:
        if isinstance(row, dict) and row.get("id"):
            out[str(row["id"])] = row
    return out


def _clause_matches(clause, text):
    if not isinstance(clause, dict) or not isinstance(text, str):
        return False
    if "equals" in clause:
        return text == clause["equals"]
    if "starts_with" in clause:
        return text.startswith(str(clause["starts_with"]))
    if "ends_with" in clause:
        return text.endswith(str(clause["ends_with"]))
    if "contains" in clause:
        return str(clause["contains"]) in text
    if "regex" in clause:
        try:
            return re.search(str(clause["regex"]), text) is not None
        except re.error:
            return False
    if "or" in clause:
        return any(_clause_matches(c, text) for c in clause["or"] or [])
    if "and" in clause:
        return all(_clause_matches(c, text) for c in clause["and"] or [])
    return False


def _candidates(text):
    names = [text]
    if "/" in text:
        names.append(text.rsplit("/", 1)[-1])
    return names


def _match_model(provider, model_id):
    models = provider.get("models") or []
    exact = []
    fuzzy = []
    names = _candidates(model_id)
    for model in models:
        if not isinstance(model, dict):
            continue
        pid = str(model.get("id") or "")
        if pid in names or model_id in (pid,):
            exact.append(model)
            continue
        if any(_clause_matches(model.get("match"), n) for n in names):
            fuzzy.append(model)
    if exact:
        return max(exact, key=lambda m: len(str(m.get("id") or "")))
    if fuzzy:
        return max(fuzzy, key=lambda m: len(str(m.get("id") or "")))
    return None


def _scalar(value):
    if isinstance(value, bool) or value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, dict) and "base" in value:
        try:
            return float(value["base"])
        except (TypeError, ValueError):
            return None
    return None


def _active_prices(prices):
    if isinstance(prices, dict):
        return prices
    if isinstance(prices, list):
        for item in reversed(prices):
            if not isinstance(item, dict):
                continue
            inner = item.get("prices")
            if isinstance(inner, dict) and not item.get("constraint"):
                return inner
        if prices and isinstance(prices[-1], dict):
            inner = prices[-1].get("prices")
            if isinstance(inner, dict):
                return inner
    return None


def _mtok_pair(prices):
    active = _active_prices(prices)
    if not active:
        return None
    inn = _scalar(active.get("input_mtok"))
    outp = _scalar(active.get("output_mtok"))
    if inn is None or outp is None:
        return None
    return inn, outp


def refresh_catalog(catalog_path: Path, write=False):
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    result = overlay(catalog)
    if result.get("ok") and write:
        catalog_path.write_text(
            json.dumps(result["catalog"], indent=1, ensure_ascii=True) + "\n",
            encoding="utf-8",
        )
    return result
