# Gap 50: vault inbound is a CPCP contract, decided before the caller

Contract definition. Did not build config-admin. Did not migrate the
REST implementation. Did not touch `.agent/secrets` or any key
material.

## Why this turn exists

0046 amendment 2 made vault's inbound a CPCP contract and left the
shape TBD. `config-admin` is vault's first caller. Built against REST
it gets written twice. Owner sequenced 50 → 5 → 15.

Row 49 already ruled KEEP BOTH: non-200 HTTP status AND a conforming
`{ok:false, reason:, because:}` envelope. The contract has to SAY that
so a later reader does not tidy the status away. Stock
`RailsCpcp::RpcController` always renders HTTP 200 — vault must not
serve refusals through it unmodified.

## Methods (map of today's surface)

| REST | method | config-admin | llm-plane |
|---|---|---|---|
| `POST /secrets` | `vault.secret.put` | yes | no |
| `GET /secrets` | `vault.secret.list` | yes | no |
| `GET /secrets/:name` | `vault.secret.get` | **no** | yes |

Allowlist keys on the method, **ahead of the store**. `get` refused to
config-admin before `Store#get`. Token is the HTTP Bearer header, not a
JSON-RPC param. No default token; fail-closed at boot. Pod-internal
only.

## Shapes named, TTL not authored

IRIs: `https://w3id.org/cpcp/osi8/vault#` (ADR 0060 convention; new
topic, not an `osi.example` successor). Not `osi.example`.
TTL waits on `ROLE=shape` (row 6). Machine copy:
`tooling/cpcp/vault_cpcp.json`.

## Seam class

Vault moved from `not_a_seam` to **decided-unbuilt**. It is not live
(`/_cpcp` unbuilt; REST still serves). It is not "not a seam" (the
inbound CPCP is decided). Authority: provider secret storage and
brokering. `domain_writer: false`. Live still 2; decided-unbuilt now 3
(`mind`, `bus`, `vault`). FRONT and `runtimes/switch` stay not-a-seam.

## Gate / plants

`check_vault_cpcp.py`. Plants: empty CHECK_ROOT; config-admin granted
`get`; refusal mapped to 200; `osi.example` IRI; 0046 reverted to TBD;
vault put back in `not_a_seam`.

Did not rebuild ROLE=vault. Did not add catalog entries. Did not touch
Gemfile.lock.
