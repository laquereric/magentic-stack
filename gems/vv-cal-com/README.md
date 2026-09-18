# vv-cal-com

Ruby client for [Cal.com](https://cal.com/) — bookings, event types,
schedules, slots, and webhooks.

CPCP: `booking.create/get/list/confirm/decline/reschedule/cancel`,
`slot.list/reserve`, `event_type.list/get`, `webhook.verify`, `embed.url`
(`Vv::CalCom::Cpcp.register!`; credentials stay in `CAL_*` env, never in params).

Cal.com publishes JS Atoms and an embed snippet. This gem is the Magentic
Market boundary: API v2 over HTTPS, snake_case at the call site, camelCase
on the wire, never-raise envelopes, HMAC webhook verify in stdlib OpenSSL.

```ruby
client = Vv::CalCom::Client.new(token: ENV["CAL_API_KEY"])

client.create_booking(
  event_type_id: 123,
  start: "2026-09-20T15:00:00Z",
  attendee: { name: "Ada", email: "ada@example.com", time_zone: "America/New_York" }
)
# => { ok: true, data: { "uid" => "…", "status" => "accepted", … } }

client.confirm_booking("booking_uid_123")
client.decline_booking("booking_uid_123", reason: "host unavailable")
client.reassign_booking("booking_uid_123", user_id: 42)
```

## Four planes

Cal.com splits the world the way a scheduling vendor does: a REST API that
owns bookings, OAuth that owns third-party access, inbound webhooks that
own the event stream, and a public booker that owns the embed.

| class | talks to | for |
|---|---|---|
| `Vv::CalCom::Client` | `https://api.cal.com/v2` | bookings, event types, schedules, slots, webhooks, teams |
| `Vv::CalCom::Oauth` | `/v2/auth/oauth2/*` | authorize URL, exchange, refresh |
| `Vv::CalCom::Webhooks` | local HMAC-SHA256 | `X-Cal-Signature-256` verify |
| `Vv::CalCom::Embed` | `cal.com/{user}/{slug}` | booking URL, iframe, popup attrs |

Teams customers get every endpoint except the ones prefixed "Platform"
and "Orgs". That is the surface this gem names. Platform (managed users,
Atoms) stopped taking new signups on 2025-12-15; `Client#call` is the
hatch for those paths, and optional `x-cal-client-id` /
`x-cal-secret-key` headers still go out when `CAL_CLIENT_ID` /
`CAL_CLIENT_SECRET` are set.

`Client#call` is also the hatch for API v2 paths this gem has not named
yet.

## Never raises

Every method returns `{ ok: true, data: }` or `{ ok: false, reason:, because: }`.
A missing key, a 401, a bad webhook signature, and a dropped packet all
take the same shape, so a caller never has to rescue.

| reason | when |
|---|---|
| `token_required` / `uri_required` | client constructed without credentials |
| `client_id_required` / `client_secret_required` | OAuth missing app credentials |
| `code_required` / `refresh_token_required` / `redirect_uri_required` | OAuth call missing an argument |
| `booking_required` / `event_type_required` / `schedule_required` / `webhook_required` / `team_required` / `slot_required` / `ooo_required` | a resource method was called without an id |
| `start_required` / `end_required` | `list_slots` missing the time range |
| `username_required` | embed URL missing a username |
| `signing_secret_required` / `webhook_headers_required` / `webhook_invalid` | webhook verify failed |
| `cal_error` | API `{ status: "error" }` (message in `because:`, `code:`) |
| `oauth_error` | RFC 6749 `{ error, error_description }` |
| `http_error` | non-2xx HTTP without a Cal.com error body |
| `timeout` / `network_error` / `json_error` | the wire failed before Cal.com answered |

```ruby
r = client.get_booking("uid_123")
if r[:ok]
  puts r[:data]["status"]
else
  warn "#{r[:reason]}: #{r[:because]}"
end
```

Paginated lists also carry `pagination:` (`nextCursor`, `hasMore`). Pass
`cursor:` on the next `list_bookings` call.

## Bookings

Create, confirm, decline, reassign, reschedule, cancel — the write
surface the originating research note asked for.

```ruby
client.create_booking(
  event_type_id: 123,
  start: "2026-09-20T15:00:00Z",
  attendee: {
    name: "Ada Lovelace",
    email: "ada@example.com",
    time_zone: "America/New_York"
  },
  booking_fields_responses: { custom_field: "hello" }
)

client.list_bookings(status: "upcoming", limit: 20)
client.get_booking("uid_123")
client.confirm_booking("uid_123")
client.decline_booking("uid_123", reason: "host unavailable")
client.reassign_booking("uid_123")                 # auto-selected host
client.reassign_booking("uid_123", user_id: 42)    # specific host
client.reschedule_booking("uid_123", start: "2026-09-21T15:00:00Z")
client.cancel_booking("uid_123", cancellation_reason: "travel")
client.mark_booking_absent("uid_123", host: true)
client.update_booking_location("uid_123", location: { type: "integration", integration: "cal-video" })
```

`create_booking` / `cancel_booking` / `reschedule_booking` are public
endpoints; a token is sent when one is configured and omitted otherwise.
Identify the event type with `event_type_id:`, or with `event_type_slug:`
plus `username:` / `team_slug:` (and optionally `organization_slug:`).

## Event types, schedules, slots

```ruby
client.create_event_type(title: "Intro", slug: "intro", length_in_minutes: 30)
client.list_event_types
client.get_event_type(123)

client.list_schedules
client.get_default_schedule
client.create_schedule(name: "Work hours", time_zone: "America/New_York", is_default: true)

client.list_slots(event_type_id: 123, start: "2026-09-20", end: "2026-09-27", time_zone: "America/New_York")
client.reserve_slot(event_type_id: 123, slot_start: "2026-09-20T15:00:00Z")
```

## Webhooks

Create them on the API, verify them locally.

```ruby
client.create_webhook(
  subscriber_url: "https://app.example/webhooks/cal",
  active: true,
  triggers: %w[BOOKING_CREATED BOOKING_CANCELLED BOOKING_RESCHEDULED],
  secret: ENV["CAL_WEBHOOK_SECRET"]
)

r = Vv::CalCom::Webhooks.verify(
  request.body.read,          # raw bytes, not re-serialized JSON
  request.headers,
  signing_secret: ENV["CAL_WEBHOOK_SECRET"]
)
if r[:ok] && r[:type] == "BOOKING_CREATED"
  sync_booking(r[:data]["payload"])
end
```

Signature is HMAC-SHA256 hex over the raw body, header
`X-Cal-Signature-256`. Most payloads wrap `{ triggerEvent, createdAt,
payload }`; `MEETING_STARTED` / `MEETING_ENDED` are flat.

## OAuth

```ruby
oauth = Vv::CalCom::Oauth.new(
  client_id: ENV["CAL_CLIENT_ID"],
  client_secret: ENV["CAL_CLIENT_SECRET"]
)

oauth.authorize_url(redirect_uri: "https://app.example/cb", state: "s1")
oauth.exchange(code: params[:code], redirect_uri: "https://app.example/cb")
oauth.refresh(refresh_token: stored)
```

Access tokens last 60 minutes; refresh tokens rotate (store the new
one). Scopes default to booking / event-type / schedule / profile /
webhook read+write. Pass `scope:` to narrow. PKCE: `code_challenge:` on
authorize, `code_verifier:` on exchange.

Use the resulting `access_token` as `Client.new(token: access_token)`.

## Embed

```ruby
Vv::CalCom::Embed.booking_url("ada", "intro")
# => { ok: true, data: "https://cal.com/ada/intro" }

Vv::CalCom::Embed.iframe_attrs("ada", "intro", height: 700)
Vv::CalCom::Embed.popup_attrs("ada", "intro", namespace: "intro")
# => { ok: true, data: { "data-cal-link" => "ada/intro", "data-cal-namespace" => "intro" } }
```

Load `{app}/embed/embed.js` (see `Embed.embed_js_url`) and either inline
an iframe or put `data-cal-link` on a button. Platform Atoms
(`@calcom/atoms`) are not wrapped — new Platform signups are closed.

## Credentials

| env | used by |
|---|---|
| `CAL_API_KEY` / `CAL_ACCESS_TOKEN` / `CALCOM_API_KEY` | `Client` |
| `CAL_API_URL` | `Client`, `Oauth` (default `https://api.cal.com`) |
| `CAL_API_VERSION` | default `cal-api-version` header (`2024-08-13`) |
| `CAL_CLIENT_ID` / `CAL_CLIENT_SECRET` | `Oauth`; Platform headers on `Client` |
| `CAL_APP_URL` | authorize URL + embed.js (default `https://app.cal.com`) |
| `CAL_ORIGIN` | booking URLs (default `https://cal.com`) |
| `CAL_WEBHOOK_SECRET` / `CAL_WEBHOOK_SIGNING_SECRET` | `Webhooks` |

An API key is `cal_…` or `cal_live_…`. Never ship it to a browser.
Rate limit is 120 requests/minute.

Self-host: point `CAL_API_URL`, `CAL_APP_URL`, and `CAL_ORIGIN` at the
instance.

## Escape hatch

Anything v2 exposes that this gem has not named:

```ruby
client.call(:post, "/v2/bookings/uid_123/guests",
            body: { guests: ["bob@example.com"] })
```

Keys are camelized the same way named methods are.

## Tests

`bundle exec rspec` — the suite is offline. It stubs HTTP and signs
local HMACs; it does not need a Cal.com instance.

## Research

The originating note is [`docs/research/CalCom.md`](docs/research/CalCom.md),
copied from magentic-market-ai research. Product: <https://cal.com/>.
API v2: <https://cal.com/docs/api-reference/v2/introduction>.
Webhooks: <https://cal.com/docs/developing/guides/automation/webhooks>.
OAuth: <https://cal.com/docs/api-reference/v2/oauth>.
