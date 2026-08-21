# Changelog

## 0.4.0 — V4

- Visuals for EvidencePanel, DecisionForm, ActionControl, Disclosure, FilterBar,
  TabSet, EmptyState, RefusalNotice, ScopeTrail, ReferentBridge
- RefusalNotice uses Profile 9 required payload shape; overridePolicy none is text
- ReferentBridge is one claim; incomplete required fields get a visible qualifier

## 0.3.0 — V3

- Visuals for PageShell, PanelFrame, SemanticText, StatusBadge, MetricStrip,
  ContextBanner, DrillDownCard, DataList, Timeline
- Payload supplement renders only hydrated declared keys; missing key is omitted
- DataList/Timeline style source children in place (no reparent)

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
