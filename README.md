# mmg-switchyard (private)

**threedot's LLM-assistance plane via NVIDIA Switchyard** — for BOTH **Develop**
(syntax/coding help) and **RUN** (runtime assistance). A threedot **CID** delivers both, and
Switchyard is the key to both: threedot uses Switchyard to get LLM assistance from a **local
(MLX) or remote** source.

## Doctrine

- **CID contract + local policy boundary stay MM-owned.**
- **Switchyard is the routing plane ONLY** (pre-alpha NVIDIA NeMo Switchyard: OpenAI↔Anthropic
  translation, local|remote backends, observability hooks).
- **Never-raise** envelopes on every boundary.

## v0 surface

| Piece | Role |
|---|---|
| `Config` | CID-derived assistance binding (model, policy, budget, format) |
| `Router.choose` | `:local` \| `:remote` from policy (default local; private stays local) |
| `Router.translate` | openai ↔ anthropic request shapes |
| `Contract` | closed request/response schema validation |
| `Observe.span` | OTEL-shaped attrs (model/source/tokens/latency/route/outcome) |
| `Adapters::*` | Source port; Local/Remote/Stub — **no live HTTP** (Switchyard pre-alpha) |
| `Client#assist` | Config → Router → Contract → adapter → Observe |
| `Mcb::Tool` | `switchyard_assist`, route, translate |

```bash
bundle install
LANG=en_US.UTF-8 bundle exec rspec
```

Design: [`docs/switchyard-design-memo.md`](docs/switchyard-design-memo.md).
LicenseRef-DataYoursSoftwareMine-1.0.
