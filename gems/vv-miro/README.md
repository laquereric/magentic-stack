# vv-miro

Private Miro boundary for Magentic. One browser load wraps every
Miro-specific call; the Ruby gem speaks REST when nobody has the board
open. Editor.js (magentic-stack / medallion-stack FRONT) does the
high-level integration only.

Miro publishes a Web SDK, a REST API, Live Embed, and (Enterprise) an
MCP server. This gem is the Magentic seam: never-raise envelopes,
snake_case at the Ruby boundary, Effects as the shared write shape.
It does not scrape miro.com's DOM.

```js
// editor.js — this is the whole integration
VvMiro.mount({
  onEvent: function (evt) {
    // evt.kind: select | create | update | delete | drop | app_card_open | …
    scheduleSave(); // existing skeleton; do not reimplement envelope
  }
});

VvMiro.applyEffect({
  op: "create",
  item: { type: "app_card", title: "CPCP call", status: "disconnected" }
});
```

```ruby
client = Vv::Miro::Client.new(access_token: ENV["MIRO_ACCESS_TOKEN"])
client.apply_effect("uXjV…", op: "create", item: { type: "sticky_note", content: "hello" })
# => { ok: true, data: { "id" => "…", … } }
```

## Why this repo exists

[`docs/research/magentic-miro-ux.md`](docs/research/magentic-miro-ux.md)
names three stacked approaches. They must not be reimplemented inside
editor.js, vv-canvas, or a magentic-stack adapter:

| Approach | When | vv-miro surface |
|---|---|---|
| **1. Web SDK app** | people are on the board | `public/vv-miro.js` `mount({ mode: "sdk" })` |
| **2. SVG onto the board** | model state needs a picture | `uploadSvg` (opaque) / `decomposeSvg` (native items) |
| **3. REST + Live Embed** | board may be closed; FRONT hosts the view | `Vv::Miro::Client` + `VvMiro.embed` |

The recommended first slice in that note is Approach 1 with **app cards**.
An app card is one CPCP call: status, evidence fields, detail modal.

This gem will be consumed by medallion-stack / magentic-stack FRONT the
same way vv-canvas ships Fabric: `Vv::Miro::Assets.install!(overlay_public)`.
Do not fork `public/vv-miro.js` into an overlay. Do not call `window.miro`
from editor.js.

## Three planes

Miro splits the world the way a board vendor does: a browser SDK that
owns live interaction, a REST API that owns durable mutation, and an
iframe that owns "show this board on our page."

| class / file | talks to | for |
|---|---|---|
| `public/vv-miro.js` | `window.miro.board` (SDK 2.0) and Live Embed iframes | events, items, app cards, SVG, embed |
| `Vv::Miro::Client` | `https://api.miro.com/v2` | boards, items, webhooks, `apply_effect` |
| `Vv::Miro::Oauth` | `https://api.miro.com/v1/oauth/*` | authorize URL, exchange, refresh, revoke |

OAuth stays on **v1** URLs. Miro says those endpoints are not deprecated.
The MCP server is Enterprise-only and prompt-driven; it is not wrapped
here (it would duplicate REST and is the wrong plane for Effects).

`Client#call` is the hatch for REST paths this gem has not named yet.

## Never raises

Every Ruby method and every public JS method returns
`{ ok: true, data: }` or `{ ok: false, reason:, because: }`. A missing
token, a 401, an unknown item type, and a dropped packet all take the
same shape, so a caller never has to rescue.

| reason | when |
|---|---|
| `token_required` / `uri_required` | client constructed without credentials |
| `client_id_required` / `client_secret_required` | OAuth missing app credentials |
| `code_required` / `refresh_token_required` / `redirect_uri_required` | OAuth call missing an argument |
| `board_required` / `item_id_required` / `webhook_required` | a resource method was called without an id |
| `op_required` / `op_unsupported` | Effect missing or unknown `op` |
| `item_type_unsupported` | item type the SDK/REST does not CRUD |
| `sdk_required` | browser load ran outside a Miro app iframe |
| `broadcast_rest_unsupported` | `op: "broadcast"` on the REST client (SDK-only) |
| `viewport_conflict` | Live Embed URL set both `moveToWidget` and `moveToViewport` |
| `miro_error` | REST `{ type: "error", code, message }` |
| `http_error` | non-2xx HTTP without a Miro error body |
| `timeout` / `network_error` / `json_error` | the wire failed before Miro answered |

```ruby
r = client.get_board("uXjV…")
if r[:ok]
  puts r[:data]["name"]
else
  warn "#{r[:reason]}: #{r[:because]}"
end
```

## Browser load (the point of the repo)

Miro serves the SDK. This gem wraps it. Two script tags, then high-level
calls:

```html
<script src="https://miro.com/app/static/sdk/v2/miro.js"></script>
<script src="/vv-miro.js"></script>
```

`public/index.html` is the headless Miro app iframe. Point the app's
Web SDK URL at a FRONT route that serves that file (or a copy installed
via `Assets.install!`).

### Component events

`mount` subscribes to Board UI events and emits a flat component event
editor.js can put on BUS. SDK methods are stripped so the payload can
cross CPCP:

```js
VvMiro.on(function (evt) {
  // evt.kind  evt.items  evt.item  evt.x  evt.y  evt.payload
});
```

| `kind` | Miro event |
|---|---|
| `select` | `selection:update` |
| `create` / `update` / `delete` | `items:create` / `experimental:items:update` / `items:delete` |
| `drop` | `drop` |
| `icon_click` | `icon:click` (opens `panelUrl` when given) |
| `app_card_open` / `app_card_connect` | app card status icon |
| `online_users` | `online_users:update` |
| `broadcast` | `board.events` custom event |
| `connect` | SDK mount succeeded |

`update` is still experimental on Miro's side (move / resize / rotate).

### Effects

The same write shape on the board (SDK) and on the wire (REST):

```js
{ op: "create"|"update"|"delete"|"sync"|"broadcast", item: { type, id?, … }, event?, payload? }
```

Supported `item.type` values: `app_card`, `sticky_note`, `shape`, `text`,
`frame`, `connector`, `image`, `card`, `embed`, `tag`.

App cards are the governance surface:

```js
await VvMiro.createAppCard({
  title: "board.put",
  description: "digest sha256:…",
  status: "disconnected",
  fields: [{ value: "pending", tooltip: "CPCP status" }]
});
// later, after MIND maps the card to a call:
await VvMiro.connectAppCard({ id: cardId });
```

### SVG (Approach 2)

```js
await VvMiro.uploadSvg(svgString, { x: 0, y: 0, width: 800 });     // opaque image
await VvMiro.decomposeSvg(svgString, { x: 0, y: 0 });              // rect/circle/text/image → items
```

Upload keeps visual fidelity and is opaque to the event layer.
Decompose is lossy on purpose so the event layer can see the parts.
Do not treat this as a full SVG engine.

### Live Embed (Approach 3, the host page)

When FRONT shows a board next to the bounded MIND view, it does not
open miro.com. It puts an iframe in the stage:

```js
VvMiro.mount({
  mode: "embed",
  host: document.getElementById("stage"),
  boardId: "uXjV…",
  autoplay: true,
  embedMode: "view_only_without_ui"
});
```

Ruby, same URL:

```ruby
Vv::Miro::Embed.url("uXjV…", embed_mode: "view_only_without_ui")
Vv::Miro::Embed.iframe_attrs("uXjV…", width: 768, height: 432)
```

## REST client

```ruby
client.list_boards(team_id: "…", limit: 10)
client.get_board("b1")
client.create_board(name: "Workshop")
client.create_app_card("b1", data: { title: "call", status: "disconnected" })
client.create_sticky_note("b1", data: { content: "hello" }, position: { x: 0, y: 0 })
client.apply_effect("b1", op: "create", item: { type: "shape", content: "N", x: 0, y: 0 })
client.list_webhooks
```

`apply_effect` is the REST twin of `VvMiro.applyEffect`. Broadcast is
SDK-only and refuses with `broadcast_rest_unsupported`; use webhooks
for durable events.

One-way share of a list of Effects (create a board, apply items,
return a view URL). Local `item.id` on creates is a caller key,
stripped before REST, and used to wire connectors:

```ruby
client.share(name: "Workshop", effects: [
  { op: "create", item: { type: "shape", id: "a", shape: "circle", x: -40, y: 0 } },
  { op: "create", item: { type: "shape", id: "b", shape: "circle", x: 40, y: 0 } },
  { op: "create", item: { type: "connector", start: { id: "a" }, end: { id: "b" } } }
])
# => { ok: true, data: { "board_id" => "…", "view_link" => "https://miro.com/app/board/…/" } }
```

`Vv::Miro::Share.push(client, name:, effects:)` is the same helper.
Use-case vocabulary does not live in this gem.

## OAuth

```ruby
oauth = Vv::Miro::Oauth.new(
  client_id: ENV["MIRO_CLIENT_ID"],
  client_secret: ENV["MIRO_CLIENT_SECRET"]
)

oauth.authorize_url(redirect_uri: "https://app.example/cb", state: "s1")
oauth.exchange(code: params[:code], redirect_uri: "https://app.example/cb")
oauth.refresh(refresh_token: stored)
oauth.context(access_token: at)
```

Store `access_token` + `refresh_token` + `team_id` + `user_id` next to
the actor. Access tokens last 60 minutes.

## Credentials

| env | used by |
|---|---|
| `MIRO_ACCESS_TOKEN` / `MIRO_TOKEN` | `Client` |
| `MIRO_CLIENT_ID` / `MIRO_CLIENT_SECRET` | `Oauth` |
| `MIRO_API_URL` | both (default `https://api.miro.com`) |

The client secret never goes to a browser. The Web SDK authorizes
inside Miro; joint SDK+REST auth is a dashboard toggle.

### Known issue: OAuth credentials travel in the query string

`Oauth#token_call` and `Oauth#revoke` pass `client_secret` — and, for
revoke, a live `access_token` — through `Transport#request(query:)`,
and `build_url` puts `query:` in the **URL**. A secret in a URL is
written to server access logs, proxy logs, and anything else that
records a request line, none of which are under this gem's control.

Two halves, and only one of them is fixed here.

- **Fixed.** `Transport` redacts `client_secret`, `access_token`,
  `refresh_token` and `code` out of any exception message before it
  reaches `because`. `URI::InvalidURIError` quotes the offending URL
  verbatim, so without this a live secret could leave the gem inside a
  refusal that gets logged or shown. Locked by a spec.
- **Open, and deliberately not changed.** The credentials should not be
  in the URL at all. RFC 6749 §2.3.1 says the client MUST send its
  credentials in the request body, and the transport already supports
  `body:` with `form: true` — but Miro's own docs describe the v1 token
  endpoint with query parameters, `spec/oauth_spec.rb` asserts `query:`
  deliberately, and the vendored research note (`docs/research/
  miro-sdk-2026.md`) does not settle which Miro accepts. Switching the
  wire format on an assumption would risk breaking a working
  integration to fix a logging exposure.

  **To close it:** confirm against Miro that `/v1/oauth/token` and
  `/v1/oauth/revoke` accept form-encoded bodies, then move the
  credential params from `query:` to `body:` with `form: true` and
  update `spec/oauth_spec.rb`. Until then, treat Miro's request logs as
  holding the client secret, and rotate it as such.

## What this gem does not do

- CPCP envelopes, `bindIfNeeded`, `showSurface`, `scheduleSave` — editor.js skeleton (CANONICAL §4.3.1).
- Fabric canvas — `vv-canvas`.
- ghis-19 widgets, SHACL, BUS, MIND — magentic-stack.
- Miro MCP — Enterprise, prompt-driven; pin separately if needed.
- Marketplace listing, Partner paperwork, BoardsPicker partnership form.

Install into an overlay:

```ruby
Vv::Miro::Assets.install!(Rails.root.join("public"))
```

That copies `vv-miro.js` and the headless `vv-miro.html`. editor.js
adds one script tag and the `mount` / `applyEffect` calls above.

## Tests

`bundle exec rake` — RSpec (offline, WebMock) plus a Node test of the
browser load against a fake `window.miro`. Neither needs a Miro board.

## Research

- [`docs/research/magentic-miro-ux.md`](docs/research/magentic-miro-ux.md) — the originating note
- [`docs/research/miro-sdk-2026.md`](docs/research/miro-sdk-2026.md) — current SDK / REST / Embed / MCP, browsed 2026-09-15

Product: <https://miro.com/>.
Developer platform: <https://developers.miro.com/>.
Web SDK: <https://developers.miro.com/docs/miro-web-sdk-introduction>.
REST: <https://developers.miro.com/docs/miro-rest-api-introduction>.
Live Embed: <https://developers.miro.com/docs/miro-live-embed-introduction>.
