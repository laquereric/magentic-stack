# Gap 5: ROLE=config is vault's first caller

Built as `ROLE=config` on the shared Rails image (ADR 0047). Host
published at `:13003`. Vault stays unpublished. Did not migrate vault
REST (row 4). Did not port catalogue/discovery/verify (row 15) — they
land on this ROLE later. Did not touch `.agent/secrets`.

## Client

`ConfigAdmin::VaultClient` speaks the gap-50 contract: `vault.secret.put`
and `vault.secret.list` only. There is no `get`. Transport is today's
REST stand-in (`GET/POST /secrets`). Row 4 swaps the transport; the
methods do not change.

Gap 104: `Net::HTTP#request` does not raise on 4xx. The body is always
parsed, so a 403 arrives as `{ok:false, reason:, because:}` plus
`status`. That is designed behaviour (config-admin is not allowlisted
for get), not an error path. Do not "fix" it by asking vault for HTTP
200. Did not change `harness.py` or `front/app.py` (they call BACK).

Stock `RailsCpcp::RpcController` is not in this path. Vault's own
controller already renders `json:` + `status:` (row 49). Config-admin
reads that body.

## Boot / routes / writers

Fail-closed: missing `VAULT_URL` / `VAULT_TOKEN`, or `SECRET_KEY_BASE`
equal to the pod default. Routes: `GET /`, `POST /secrets`. Not
`/_cpcp`, not `GET /secrets/:name`. `domain_writers.json` `config`
writes nothing.

Switch `:13001` stays until row 11. Extract FRONT `:13000` stays the
web page. 0046's "only published port" is vs vault (vault unpublished).

## Gate / plants / spec

`check_config_vault_client.py`. Plants: empty CHECK_ROOT; get added to
ALLOWED; `urlopen` instead of `request`. mind-pod `config_admin_spec.rb`.

Did not touch Gemfile.lock.
