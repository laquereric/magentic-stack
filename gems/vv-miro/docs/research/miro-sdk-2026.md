# Miro Developer Platform as of 2026-09-15

Browsed from [developers.miro.com](https://developers.miro.com/) and
[developers.miro.com/llms.txt](https://developers.miro.com/llms.txt). The
originating product brief is [`magentic-miro-ux.md`](magentic-miro-ux.md).

## Surfaces (four, not two)

The 2026 platform is four seams. The original UX note named Web SDK vs REST.
MCP and Live Embed are first-class now.

| Surface | Runs | Board must be open | vv-miro |
|---|---|---|---|
| **Web SDK 2.0** | Browser, inside a Miro app iframe | Yes | `public/vv-miro.js` |
| **REST API v2** | Any backend | No | `Vv::Miro::Client` |
| **Live Embed** | iframe on a host page | Viewer must load it | `Vv::Miro::Embed` / `VvMiro.embed` |
| **MCP Server** | AI coding tools (Enterprise only) | No | **out of scope** — prompt-driven, not a deterministic Effect plane |

Do not scrape miro.com's DOM. Miro's [app development policy](https://developers.miro.com/docs/app-development-policy) is the reason; Web SDK / REST / Live Embed are the allowed seams.

## Web SDK 2.0 (current)

Loader (do not vendor):

```
https://miro.com/app/static/sdk/v2/miro.js
```

`window.miro.board` is the v2 surface. `window.miro.v1` is the retired SDK.

CRUD on items: app card, card, connector, embed, frame, image, mindmap, preview, shape, sticky note, tag, text. Not yet: comments, kanban, stroke, SVG-as-item, table, USM, wireframe, and several beta widgets (doc/slides/table/timeline on the Web SDK). REST has since added **doc format** items; the Web SDK has not.

Board UI events this gem maps to component events:

| SDK event | component `kind` |
|---|---|
| `selection:update` | `select` |
| `items:create` | `create` |
| `experimental:items:update` | `update` (move/resize/rotate only, still experimental) |
| `items:delete` | `delete` |
| `drop` | `drop` |
| `icon:click` | `icon_click` |
| `app_card:open` | `app_card_open` |
| `app_card:connect` | `app_card_connect` |
| `online_users:update` | `online_users` |
| `board.events` custom | `broadcast` |

`sync()` is required after mutating an item. App cards default to `status: "disconnected"` until the app maps them to a data source.

Realtime `board.events.broadcast` is **not** a REST webhook. It only fires while the board is open and the app is running. Durable automation uses REST webhooks (`/v2/webhooks/subscriptions`).

## REST v2

Base: `https://api.miro.com/v2`. Auth: `Authorization: Bearer {access_token}`.

OAuth 2.0 **stays on v1** and is not deprecated:

- authorize: `https://miro.com/oauth/authorize`
- token / refresh: `https://api.miro.com/v1/oauth/token`
- revoke: `https://api.miro.com/v1/oauth/revoke`
- context: `GET https://api.miro.com/v1/oauth-token`

Access tokens expire in 60 minutes; refresh tokens last 60 days. Joint Web SDK + REST authorization is a dashboard toggle ("Use this URI for SDK authorization").

Error body: `{ type: "error", code, message, status, context? }`.

New since the original UX note: bulk item create (up to 20, transactional), groups, doc format items, REST webhooks.

## Live Embed

```
https://miro.com/app/live-embed/{board_id}?autoplay=true&embedMode=view_only_without_ui
```

`moveToWidget` and `moveToViewport` are mutually exclusive. `embedMode=view_only_without_ui` is experimental. BoardsPicker needs a Miro partnership form; direct-link embed does not.

## MCP (not wrapped)

Enterprise-only, OAuth 2.1 inside the MCP client, AI credits for `context_get`. It can generate diagrams from a DSL in one prompt and read comments (REST cannot). It is the wrong plane for Magentic Effects: non-deterministic, plan-gated, and it would duplicate REST. If MIND ever needs it, pin it as a separate adapter, not inside this gem.

## Marketplace

Approach 1 (Web SDK app + app cards) is the listing path. Partner status is required to submit.

## What magentic-stack / medallion-stack must not copy

- `window.miro.*` calls
- Live Embed URL construction
- SVG → base64 / native-item decomposition
- App-card status transitions
- REST path + camelCase mapping
- OAuth token exchange

Those live here. Editor.js calls `VvMiro.mount` / `VvMiro.applyEffect` and maps component events onto the existing CPCP envelope. SHACL, BUS, ghis-19, and `envelope` / `bindIfNeeded` / `showSurface` stay in the stack.
