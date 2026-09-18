# Changelog

## Unreleased

- `Vv::CalCom::Cpcp.register!` — CPCP projection (`booking.*`, `slot.*`,
  `event_type.*`, `webhook.verify`, `embed.url`). No-op when rails-cpcp
  is absent. Credentials stay in `CAL_*` env, never in params.

## 0.1.0 — 2026-09-17

First cut. REST v2 Ruby client for the Cal.com API.

- `Vv::CalCom::Client` — API v2 (bookings, event types, schedules, slots, webhooks, me, teams, out-of-office)
- `Vv::CalCom::Oauth` — authorization-code + refresh (`/v2/auth/oauth2/token`)
- `Vv::CalCom::Webhooks` — HMAC-SHA256 `X-Cal-Signature-256` verify
- `Vv::CalCom::Embed` — booking URL, iframe attrs, popup `data-cal-link`
- Never-raise envelopes; snake_case at the Ruby boundary, camelCase on the wire
