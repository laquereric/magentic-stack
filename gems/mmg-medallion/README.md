# mmg-medallion

**Semantic Medallion** — a Bronze → Silver → Gold projection plane over **RDF triples**.

Migrates + supersedes **vv-medallion** (`Flow` registry · `Conformer` Bronze→Silver · `Curator`
Silver→Gold · `audit!`), evolving it into a triple-native ("semantic") medallion that composes with
`Mm::GraphMemory`, `Mmg::Curation`, and SHACL. Storage stays separate (data plane); this owns
**projection** (read-model build).

Stage-1 scaffold: empty `isolate_namespace` engine, boots green. Migration + semantic next-step
research (from mmg-manus) land in [`docs/research/`](docs/research/).

## Purpose-based layering
The medallion is a **Build** layer; each tier earns its place by a unique state-change — Bronze=landing
(never transforms), Silver=transform (first decision, `Conformer`), Gold=semantic model + contract
(`Curator`, the define-once truth). `audit!` rejects maximalist stacking. See
[`docs/PURPOSE_LAYERING.md`](docs/PURPOSE_LAYERING.md) (integrates `docs/research/DataLayer.md`).
