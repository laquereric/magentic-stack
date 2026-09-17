# Figma developer surfaces (browsed 2026-09-16)

**Sources:** [Authentication](https://developers.figma.com/docs/rest-api/authentication/) ·
[OAuth apps](https://developers.figma.com/docs/rest-api/oauth-apps/) ·
[Scopes](https://developers.figma.com/docs/rest-api/scopes/) ·
[File endpoints](https://developers.figma.com/docs/rest-api/file-endpoints/) ·
[OAuth with Plugins](https://developers.figma.com/docs/plugins/oauth-with-plugins/)

vv-figma is the pinned seam that implements this note. Do not re-derive
Figma calls in magentic-stack editor.js.

## The Figma constraint that shapes everything

| | Plugin API | REST API |
|---|---|---|
| Live interaction with users in the file | Yes | No |
| Document nodes (rect, frame, text) | Yes | No |
| File may be closed | No | Yes |
| Backend hosting | Not required | Required |
| Language | JavaScript in sandbox + UI iframe | Any |

REST reads files and writes comments / webhooks / variables. It does
**not** create a file or a rectangle. Share.push therefore takes an
existing `file_key`.

## OAuth

- Authorize: `https://www.figma.com/oauth`
- Token: `POST https://api.figma.com/v1/oauth/token` (HTTP Basic,
  `application/x-www-form-urlencoded`). Codes expire in **30 seconds**.
- Refresh: `POST https://api.figma.com/v1/oauth/refresh`. Figma keeps
  one access token per app per user; refresh invalidates the previous
  access token.
- Plugin OAuth cannot open a browser or listen on localhost; the plugin
  talks to **your** server, which holds the client secret.

## Auth headers

- Personal access token: `X-Figma-Token`
- OAuth access token: `Authorization: Bearer`
- Plan access token (Organization / Enterprise): not modeled here yet

## Embed

`https://www.figma.com/embed?embed_host=…&url=https://www.figma.com/file/{key}`

Do not scrape figma.com's DOM.
