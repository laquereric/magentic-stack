# gems/adapters/nemo-switchyard/  🟢 OWN IT

Wraps the NVIDIA NeMo Switchyard pin. This directory is the only place
that may reach `upstreams/` for that pin (ADR 0038). The gitlink path
is `submodule_path` in `upstreams/manifests/nemo-switchyard.pin.json`.

## v1 (Shape D)

- `switchyard-server` listens on loopback `:4000` (pin default).
- Node leftover reverse-fronts `/v1/*` on unpublished `:8789`.
- UI / discovery / verify stay on pod-internal `:8790` (host `:13001`
  retired, row 11 slice C).
- Algorithms: `noop`, `passthrough`, `random` only. Judge
  (`llm_classifier`) and escalation (`stage_router`) are gated off.
- Keys live in vault (`switchyard.<vendor>`); `.agent/secrets:/state`
  keeps non-key routing state. `inject_env.mjs`
  copies vendor keys into the env vars the pin's TOML names. Do not
  touch `.agent/secrets` in this tree.
- `language_rule.json` stays `kind=violation` (Node leftover remains).

Build the pin from the submodule; do not fork or edit `upstreams/`.
