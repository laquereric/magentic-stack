# presentation/ — vv-graph membrane layer (P1)

Per [biological-interface-gem](../../../docs/architecture/principles/biological-interface-gem.md)
P1, a gem may ship three packs: library / engine / **presentation**.

## Status (cut 4)

**Present as a documented layer, intentionally thin.** vv-graph is a grammar/data
leaf (MCB + AR + graph). It does **not** own browser Stimulus controllers or
ERB partials yet — peers render via mmg-sal / host Rails, reading this gem's
**public graph** and MCB actions only.

| Layer | Path | Role |
| --- | --- | --- |
| library | `lib/` | pure logic, SHACL, loss markers, pattern exec |
| engine | `app/` (Rails engine when present) | AR models + services |
| presentation | `presentation/` (this dir) | future host-facing partials / SAL adapters |

## Rule

Presentation may depend on engine; engine may depend on library; library
depends on neither. Do not reach into `lib/` from other gems — call MCB or
SPARQL the public named graph.

## When to grow this folder

Add ERB/Stimulus/SAL partials here only when a human-facing surface is owned
by **this** gem (not the host). Until then, this README is the P1 honesty
marker (layer present, content deferred).
