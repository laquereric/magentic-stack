# Changelog

## 0.2.0 — V2

- Parse `<script type="application/ld+json" data-ux-acia-document>`
- Join `props.valueJson` to elements by `nodeId` / `data-ux-node-id`
- Safety gate: no block, malformed (incl. missing `document.rootNode`), correlation/digest mismatch — refuse all hydration, never throw
- No visual payload rendering

## 0.1.0 — V1

- Gem skeleton
- `vv-component-runtime` custom element with closed-shadow `<template>` registry
- `.ux-render-root` scan and adapter registry keyed by `data-ux-component-kind`
- Token set as CSS custom properties, light and dark via `prefers-color-scheme`
- No component visuals yet
- Degradation: missing include, unknown 20th kind, empty page — none throw
