# vv-cal-com — Cal.com scheduling on the CPCP seam

**Built as `gems/vv-cal-com`.** Never-raise Ruby client for the Cal.com
API v2 (bookings, event types, schedules, slots, webhooks, teams),
OAuth 2.0, HMAC webhook verify, and embed URLs. Snake_case at the Ruby
boundary, camelCase on the wire. Gate: `tooling/cal-com/cal_com_seam_probe.rb`.
Count gate: `tooling/governance/check_doc_counts.py`.

The split follows [`plan_vv-perch.md`](plan_vv-perch.md) (schema gem, seam
outside it): the gem owns the client and the projection
(`Vv::CalCom::Cpcp.register!`), BACK owns the mount (the mind-pod
`rails_cpcp` initializer calls it when defined, same as Canvas/Browser).
Thirteen, and the count is load-bearing — §1 lists every projected operation.

Source: Cal.com API v2 (<https://cal.com/docs/api-reference/v2/introduction>),
webhooks (<https://cal.com/docs/developing/guides/automation/webhooks>),
OAuth (<https://cal.com/docs/api-reference/v2/oauth>). The originating
research note ships with the gem (`gems/vv-cal-com/docs/research/CalCom.md`).

---

## 1. The operations

| operation | direction | required params | notes |
|---|---|---|---|
| `booking.create` | push | `operationId eventTypeId start` | public endpoint; token sent when configured |
| `booking.get` | pull | `uid` | |
| `booking.list` | pull | — | optional `status` |
| `booking.confirm` | push | `operationId uid` | |
| `booking.decline` | push | `operationId uid` | optional `reason` |
| `booking.reschedule` | push | `operationId uid start` | optional `reason` |
| `booking.cancel` | push | `operationId uid` | optional `reason` → `cancellationReason` |
| `slot.list` | pull | `eventTypeId start end` | refused before the wire without a range |
| `slot.reserve` | push | `operationId eventTypeId slotStart` | hold a slot before booking it |
| `event_type.list` | pull | — | |
| `event_type.get` | pull | `id` | |
| `webhook.verify` | pull | `body signature` | local HMAC-SHA256, no network |
| `embed.url` | pull | `username` | public booking URL, no network |

## 2. Three rules the seam keeps

**Credentials never travel in params.** Every handler builds `Client.new`
with no arguments, which reads `CAL_API_KEY` / `CAL_API_URL` from the
environment. No projected operation declares a token, key, or secret
param, so there is nowhere to put one — and nothing secret-shaped lands
in the idempotency store or the call log. The probe asserts this
(`no-operation-takes-credentials`).

**Writes name their intent.** Every push requires `operationId`; a push
without one is refused before any handler runs. Reads need no intent,
but they still need their identifiers — enforced by the dispatcher,
before the wire.

**Never raises across the boundary.** Handler results flow through the
dispatcher verbatim as the JSON-RPC result, so the gem's
`{ ok:, data: } / { ok:, reason:, because: }` envelopes are what the
caller branches on. A forged webhook is a refusal inside an ok
envelope, not a crash.

## 3. What it refuses to project

- **OAuth over CPCP.** `Vv::CalCom::Oauth` stays direct-Ruby: authorization
  codes and refresh-token rotation are credential handling, and
  credential handling does not cross this seam (rule 1).
- **The `client.call` escape hatch.** Arbitrary method/path pairs are
  for direct Ruby callers; a seam that forwards anything cannot state
  what it exposes (§1 would be a lie).
- **Platform Atoms** (`@calcom/atoms`): closed to new signups; the gem
  does not wrap them and neither does the seam.

## 4. Offline by construction

The probe dispatches only calls that terminate before the wire
(unknown operation, missing params, missing `operationId`) plus the two
local handlers. Anything that would perform HTTPS is covered by the gem
specs with an injected `FakeTransport` instead (`gems/vv-cal-com/spec/cpcp_spec.rb`,
19 examples; WebMock bans the network in `spec_helper.rb`).
