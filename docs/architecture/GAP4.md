# Gap 4: vault inbound is live CPCP

Transport-only. Methods are still `vault.secret.put` / `list` / `get`.
Allowlist still keys on the method, ahead of the store. Config-admin
still cannot get. Bearer still the header, not a param. Refusals still
non-200 plus `{ok, reason, because}`.

## What changed

ROLE=vault draws `POST /_cpcp/rpc` on `VaultCpcpController`. It does
**not** mount `RailsCpcp::Engine` — stock `RpcController` always
renders HTTP 200, which is the named hazard for a refused credential
read.

REST `/secrets` is gone. `ConfigAdmin::VaultClient` POSTs JSON-RPC to
`/_cpcp/rpc` and still parses every status. Vault is a **live** seam,
not decided-unbuilt.

401 includes `WWW-Authenticate: Bearer`. Envelope stays the vault
contract (flat `ok`/`reason`/`because`/`result`) plus `jsonrpc`/`id`.
Not a copy of BACK's nested `Envelope.fail`.

## What did not change

Allowlist operations remain `put`/`list`/`get`. Store is still
encrypted JSON on the bind mount. Port unpublished. No TTL (row 6).
Did not touch `.agent/secrets` or vault contents. Did not add `get` to
config-admin. Did not flip BACK `RpcController`.

## Gate / specs

`check_vault_cpcp.py` (vault live, not stock controller, no REST).
`check_config_vault_client.py` (POST `/_cpcp/rpc`, no get).
`vault_spec.rb`. `role_routes.json` vault is POST `/_cpcp/rpc` only.
