---
id: "0018"
title: Review is a static script over the rendered page
status: accepted
date: 2026-08-26
subject_kind: gem
subject: vv-html-components
components: [vv-html-components]
paths:
  - gems/vv-html-components/lib
  - gems/vv-html-components/dist
enforced_by:
  - gems/vv-html-components/spec/v1_spec.rb
supersedes: null
superseded_by: null
---

## Context

A review surface over an ACIA page could be built into the renderer. Then the
renderer serves two masters: producing the page, and producing the affordances
for inspecting it. Every review feature becomes a renderer change, and the P9
gate (ADR 0007) now has to admit component kinds that exist only for reviewing.

## Decision

A **single static script** that turns an already-rendered Profile 9 page into a
review surface, without changing the renderer. It reads the node attributes the
renderer already emits. The demo opens from the filesystem with no server.

## Consequences

- Review evolves without touching the renderer or the vocabulary.
- It depends on the rendered DOM shape, so a renderer change to node attributes
  can break it silently. That coupling is the price of the separation, and it is
  narrower than the alternative.
- No server means the surface can be opened against a saved page.
