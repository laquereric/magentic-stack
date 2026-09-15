# Changelog

## 0.1.0 — 2026-09-15

First cut. Three planes, one repo:

- Browser load (`public/vv-miro.js`) wraps Miro Web SDK 2.0 and Live Embed.
- Ruby REST v2 client (`Vv::Miro::Client`) for boards that may be closed.
- OAuth 2.0 (`Vv::Miro::Oauth`) stays on Miro's v1 token endpoints.

Editor.js / magentic-stack FRONT is not in this gem. It loads the
browser file and calls `VvMiro.mount` / `VvMiro.applyEffect`.
