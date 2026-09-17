# vv-figma

**Home: magentic-stack (ADR 0038).** Origin: `laquereric/vv-figma` (standalone
private copy; non-authoritative).

Private Figma boundary for Magentic. One browser load wraps every
Figma-specific call; the Ruby gem speaks REST when nobody has the file
open. Editor.js does the high-level integration only.

This repo **mirrors [vv-miro](https://github.com/laquereric/vv-miro)**:
never-raise envelopes, snake_case at the Ruby boundary, Effects as the
shared write shape. It does not scrape figma.com's DOM.

Figma is not Miro. REST cannot create a file or a rectangle. The Plugin
API can. Effects that would mint document nodes refuse `plugin_required`
on REST instead of pretending.

```js
// editor.js — this is the whole integration
VvFigma.mount({
  onEvent: function (evt) {
    // evt.kind: select | page | update | close | …
    scheduleSave();
  }
});

VvFigma.applyEffect({
  op: "create",
  item: { type: "rectangle", name: "Use case", x: 40, y: 80, width: 220, height: 90 }
});
```

```ruby
client = Vv::Figma::Client.new(access_token: ENV["FIGMA_ACCESS_TOKEN"])
client.get_file("AbCdEf123")
# => { ok: true, data: { "name" => "…", "document" => … } }

client.share(file_key: "AbCdEf123", effects: [
  { op: "create", item: { type: "comment", message: "UC-SAS-1 S3" } }
])
# => { ok: true, data: { "file_key" => "AbCdEf123", "view_link" => "https://www.figma.com/file/AbCdEf123/" } }
```

## Why this repo exists

vv-miro is the pinned Miro seam. Figma needs the same seam, not a copy
inside editor.js or an overlay:

| Approach | When | vv-figma surface |
|---|---|---|
| **1. Plugin API** | people are in the file | `public/vv-figma.js` `mount({ mode: "plugin" })` |
| **2. Embed** | FRONT hosts a view | `Vv::Figma::Embed` / `VvFigma.embed` |
| **3. REST** | file may be closed | `Vv::Figma::Client` |

Do not fork `public/vv-figma.js` into an overlay. Do not call `figma`
from editor.js.

## Planes

| | Runs | File must be open | vv-figma |
|---|---|---|---|
| **Plugin API** | Plugin sandbox + UI iframe | Yes | `public/vv-figma.js` |
| **REST API** | Any backend | No | `Vv::Figma::Client` |
| **Embed** | iframe on a host page | Viewer must load it | `Vv::Figma::Embed` |

OAuth stays on `https://www.figma.com/oauth` + `POST /v1/oauth/token`
(HTTP Basic). Personal access tokens use `X-Figma-Token`; OAuth tokens
use `Authorization: Bearer`. The transport sends both.

## REST vs plugin (the split that shapes everything)

| Effect | Plugin | REST |
|---|---|---|
| create rectangle / ellipse / text / frame | Yes | `plugin_required` |
| update / delete a node | Yes | `plugin_required` |
| create comment | — | Yes |
| read file / nodes / images | — | Yes |
| broadcast to UI | Yes | `broadcast_rest_unsupported` |
| create a new file | No public API | `file_required` on Share.push |

`Share.push` therefore **requires an existing `file_key`**. It does not
mint a Figma file.

## Credentials

| ENV | Plane |
|---|---|
| `FIGMA_ACCESS_TOKEN` / `FIGMA_TOKEN` | REST |
| `FIGMA_CLIENT_ID` / `FIGMA_CLIENT_SECRET` | OAuth |
| `FIGMA_API_URL` | both (default `https://api.figma.com`) |

The client secret never goes to a plugin iframe.

## Install into an overlay

```ruby
Vv::Figma::Assets.install!(Rails.root.join("public"))
```

That copies `vv-figma.js`, `vv-figma.html`, `vv-figma-code.js`, and
`vv-figma-manifest.json`. editor.js adds one script tag and the
`mount` / `applyEffect` calls above.

This overlay app is **not** wired yet.

## Tests

`bundle exec rake` — RSpec (offline, WebMock) plus a Node test of the
plugin load against a fake `figma` global. Neither needs a Figma file.

## Research

- [`docs/research/figma-api-2026.md`](docs/research/figma-api-2026.md)

Product: <https://www.figma.com/>.
REST: <https://developers.figma.com/docs/rest-api/>.
Plugin API: <https://developers.figma.com/docs/plugins/>.
OAuth: <https://developers.figma.com/docs/rest-api/authentication/>.
