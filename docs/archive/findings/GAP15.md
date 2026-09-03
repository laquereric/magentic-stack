# Gap 15: catalogue ports to ROLE=config; discovery and verify stay

The table moved. The credential-bearing two did not. None of the three
were dropped.

## What moved

`runtimes/mind-pod/app/config/llm_catalog.json` is the vendor / model /
price / tools table. `ROLE=config` serves `GET /catalog` (HTML and
JSON). Display only. Indicative prices, not a billing source of truth.
`tools: false` on `qwen2.5:3b` and `llama3.2:1b` is observed failure,
not an assumption.

`catalog.mjs` still exists on switch as the routing helpers
(`modelSpec`, `estimateTokens`, `estimateCost`). It loads the JSON. It
does not contain a second table. The switch image COPYs the
config-owned file so the container has it at `/switch/llm_catalog.json`.
There is no `runtimes/switch/llm_catalog.json` in source.

## What stayed

`discovery.mjs` still asks the vendor which models a key opens (the
hardcoded list shipped a 404). `verify.mjs` still probes tool support
on demand (never automatic; billed). Both still live with
switch/router, which holds `state.keys`. Config does not egress, does
not call `complete`, does not add `vault.secret.get`.

0046 already permits the UI to *show* test results. This turn does not
add a config-to-switch RPC to fetch them.

## What was not done

Did not relax the read-back asymmetry. Did not touch `.agent/secrets`.
Did not migrate vault REST. Did not flip RpcController. Did not port
discovery or verify. Did not invent a probe RPC.

## Gate / plants / spec

`check_config_catalog.py`. Plants: empty CHECK_ROOT; inline table back
in `catalog.mjs`; `discovery.mjs` dropped; config controller egresses;
a second copy under `runtimes/switch/`; Dockerfile COPY removed.
`config_admin_spec.rb` covers load + `GET /catalog`.
