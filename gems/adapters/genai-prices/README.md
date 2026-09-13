# gems/adapters/genai-prices/  🟢 OWN IT

Boundary adapter for the pydantic/genai-prices **data** pin.

This directory is the only place that may reach the overlay snapshot
`data_slim.json`. ROLE=config still owns
`runtimes/mind-pod/app/config/llm_catalog.json`. `catalog.mjs` still
loads that JSON and no other table.

`overlay(catalog)` returns a never-raise envelope and a new catalog
with `in`/`out` filled from USD-per-million `input_mtok`/`output_mtok`.
It does not add vendors or models. Local vendors and OpenRouter stay
untouched (zeros are "not billed"; OpenRouter prices must remain
unknown).

```bash
python3 gems/adapters/genai-prices/tests/test_overlay.py
```

The pin record is `upstreams/manifests/genai-prices.pin.json`
(`kind: data`). Lift `pinned_version` and `data_sha256` together.
