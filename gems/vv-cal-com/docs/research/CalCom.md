# Cal.com

Source note from magentic-market-ai research:

https://cal.com/

https://github.com/calcom

Cal.com is the strongest answer for most cases, mainly because it's the only major option where a real write-capable API isn't gated behind an enterprise tier.

Why it wins on API + cost

The v2 API does real programmatic booking — creating, confirming, declining, reassigning and updating bookings, with auth via API keys, managed-user tokens, or OAuth, plus webhooks and embeddable React components.
Cal.com
Teams customers get every endpoint except the ones prefixed "Platform" and "Orgs", so a $15/user/month plan (about $12 annually) buys you nearly the whole API surface. Organizations is $37/user/month.
Introduction to API v2 - Cal.com Docs +2
The free plan is unusually generous — unlimited event types and the core booking experience at no cost, and it's open source, so self-hosting is $0 in license terms. Rate limits are 120 requests/minute on an API key, raisable to roughly 200.
Tomba
Cal.com
Worth knowing: Cal.com has stopped taking new signups for any "Platform" plan (that was the $299/month multi-tenant tier), which is good news for cost but means the white-label/managed-users path is now murkier for new builders. And self-hosting is not really free once you account for the DevOps work to run and maintain it.
Cal.com
Knock-ai

## Why a Ruby client

Cal.com ships first-party SDKs for JS/TS (Atoms, embed-react) and an MCP server. There is no first-party Ruby client. Magentic Market's gem galaxy is Ruby, so this repo is the boundary: API v2 over HTTPS, snake_case at the call site, camelCase on the wire, never-raise envelopes, HMAC webhook verify in stdlib OpenSSL.

## Four planes

Documented at https://cal.com/docs/api-reference/v2/introduction
and https://cal.com/docs/developing/guides/automation/webhooks.

| plane | URL | auth | this gem |
|---|---|---|---|
| API v2 | `https://api.cal.com/v2` | API key `cal_*` / `cal_live_*`, or OAuth access token | `Vv::CalCom::Client` |
| OAuth 2.0 | `POST /v2/auth/oauth2/token` | client id + secret (or PKCE) | `Vv::CalCom::Oauth` |
| Webhooks | inbound | HMAC-SHA256 secret, `X-Cal-Signature-256` | `Vv::CalCom::Webhooks` |
| Embed | `https://cal.com/{user}/{slug}` + `embed.js` | none | `Vv::CalCom::Embed` |

Platform Atoms (`@calcom/atoms`) and managed users are out of v0.1. Cal.com stopped new Platform signups on 2025-12-15. `Client#call` covers remaining Platform paths for existing customers (`x-cal-client-id` / `x-cal-secret-key`).

Teams customers get every endpoint except those prefixed "Platform" and "Orgs". That is the surface this gem names.

## Wire contract (API v2)

- Base: `https://api.cal.com` (self-host: `CAL_API_URL`)
- `Authorization: Bearer ${CAL_API_KEY}` — key is `cal_…` (test) or `cal_live_…`
- JSON bodies, **camelCase** keys (`eventTypeId`, `timeZone`, `subscriberUrl`, `bookingFieldsResponses`)
- `cal-api-version` header. Default pin is `2024-08-13`. Named methods send the version the current OpenAPI requires for that resource (bookings `2026-02-25` / list `2026-05-01`, event types `2026-06-12`, slots `2024-09-04`).
- Success: `{ "status": "success", "data": … }` with optional `pagination: { nextCursor, hasMore }`
- Failure: `{ "status": "error", "error": { "message", "code" } }` on 4xx/5xx
- OAuth token endpoint is a raw RFC 6749 object (`access_token`, `token_type`, `refresh_token`, `expires_in`, `scope`) — no `status` wrapper
- Rate limit: 120 requests/minute on an API key (raisable)

Some booking/slot endpoints are public (create, cancel, reschedule, list slots). Auth is optional there; a token is still sent when one is configured.

## Everyday API v2 paths

| resource | method | path |
|---|---|---|
| bookings | GET / POST | `/v2/bookings` |
| booking | GET | `/v2/bookings/{uid}` |
| confirm / decline / cancel / reschedule | POST | `/v2/bookings/{uid}/{confirm,decline,cancel,reschedule}` |
| reassign | POST | `/v2/bookings/{uid}/reassign`, `…/reassign/{userId}` |
| mark absent / location | POST | `/v2/bookings/{uid}/mark-absent`, `…/location` |
| event types | GET / POST / PATCH / DELETE | `/v2/event-types`, `/v2/event-types/{id}` |
| schedules | GET / POST / PATCH / DELETE | `/v2/schedules`, `/v2/schedules/default`, `/v2/schedules/{id}` |
| slots | GET | `/v2/slots?eventTypeId=&start=&end=` |
| slot reservations | POST / GET / PATCH / DELETE | `/v2/slots/reservations`, `…/{uid}` |
| webhooks | GET / POST / PATCH / DELETE | `/v2/webhooks`, `/v2/webhooks/{id}` |
| me | GET / PATCH | `/v2/me` |
| teams | GET / POST / PATCH / DELETE | `/v2/teams`, `/v2/teams/{id}` |
| OAuth authorize | GET | `https://app.cal.com/v2/auth/oauth2/authorize` |
| OAuth token | POST | `/v2/auth/oauth2/token` |

## Webhooks

Cal.com POSTs `{ triggerEvent, createdAt, payload }` (MEETING_STARTED / MEETING_ENDED are flat). Signature is HMAC-SHA256 hex of the **raw body**, header `X-Cal-Signature-256`. Payload version is `x-cal-webhook-version` (`2021-10-20` or `2026-07-27`). Secret is set when the webhook is created.

## Embed

Public booker: `https://cal.com/{username}/{eventSlug}`. Script: `{app}/embed/embed.js`. Popup uses `data-cal-link`. Platform Atoms are not wrapped.

## Credentials

| env | used by |
|---|---|
| `CAL_API_KEY` / `CAL_ACCESS_TOKEN` / `CALCOM_API_KEY` | `Client` |
| `CAL_API_URL` | `Client`, `Oauth` (default `https://api.cal.com`) |
| `CAL_API_VERSION` | optional default `cal-api-version` |
| `CAL_CLIENT_ID` / `CAL_CLIENT_SECRET` | `Oauth`; also Platform headers on `Client` |
| `CAL_APP_URL` | `Oauth#authorize_url`, embed.js (default `https://app.cal.com`) |
| `CAL_ORIGIN` | `Embed` booking URLs (default `https://cal.com`) |
| `CAL_WEBHOOK_SECRET` / `CAL_WEBHOOK_SIGNING_SECRET` | `Webhooks` |

## Not in v0.1.0

Platform managed users, Platform OAuth clients, Orgs-prefixed endpoints, Atoms / BookerEmbed React components, MCP (`mcp.cal.com`), conferencing OAuth handshakes, Stripe connect, insights, credits, routing-form responses, workflows. `Client#call` covers those paths until they earn a named method.
