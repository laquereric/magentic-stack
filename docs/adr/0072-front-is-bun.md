---
id: "0072"
title: FRONT is a Bun container; Rails FRONT is a proxy-only stopgap
status: accepted
date: 2026-09-14
subject_kind: doctrine
subject: FRONT runtime language
components: [front, rails-base, front-base]
paths:
  - runtimes/front-base
  - docs/architecture/CANONICAL.md
  - docs/adr/0047-three-languages-container-boundaries-own-images.md
enforced_by:
  - tooling/compose/check_language_rule.py
  - tooling/pins/published_images.json
supersedes: null
amends: "0047"
---

# FRONT is a Bun container; Rails FRONT is a proxy-only stopgap

## Conflict this ADR names

[ADR 0047](0047-three-languages-container-boundaries-own-images.md)
assigns Ruby/Rails to “everything else”, including FRONT. The
browser carve-out covers in-page JS, not a FRONT **container**.

[CANONICAL.md](../architecture/CANONICAL.md) says FRONT is Bun.
Until this amendment, those two files disagreed. This is the
human ADR CANONICAL_GAPS G0 required. It is not a silent rewrite
of 0047.

## Decision

1. **FRONT is a container whose language is Bun** (JavaScript
   runtime). One image: `front-base`. Overlays `FROM` that digest.
2. **BACK and BACKJOB stay Rails.** Compile, journal, `ui.*`,
   `front.*`, blob, board stay on BACK.
3. **The browser carve-out in 0047 remains.** In-page JS
   (`vv-html-components`, skeleton, Stage override) is still not
   a fourth container language. Bun is how that JS is **served
   and packed**.
4. **`ROLE=front` on a Rails image is a proxy-only stopgap.** It
   is not the application host. New overlays do not add ERB
   product chrome on Rails FRONT.
5. **SWITCH remains a known 0047 violation** (Node, target Rust).
   This ADR does not clear that row.

## Why Bun, not Rails FRONT

ADR 0047’s own rule 3 is one image per container. Sharing
`mind-pod:latest` / `rails-base` across BACK and FRONT is the
coupling 0047 already named. A catalog host (19 widgets +
skeleton) is a different deployable than a CPCP writer. A Bun
FRONT image can hot-patch UI without rebuilding GEM_HOME.

## Consequences

- Publish `front-base` in `tooling/pins/published_images.json`.
- `FLOOR-FRONT.json` is a human pin, same posture as
  `runtimes/rails-base/FLOOR.json`. Do not auto-bump.
- `tooling/compose/language_rule.json` maps `front` →
  `javascript`. That is the amendment, not an exemption.
- Shared AI Space may keep a Rails FRONT proxy until its
  `Dockerfile.thin` grows a FRONT stage `FROM front-base@sha256:…`.
